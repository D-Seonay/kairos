import CoreLocation
import Foundation
import HealthKit
import PulseDomain

/// La séance HealthKit d'une course (spec V2a) : une `HKWorkoutSession` de course en extérieur et son builder en direct, qui
/// livre la FC. La distance du podomètre n'est pas collectée : seule la distance GPS filtrée de Pulse arrive dans Santé, avec
/// le tracé. `HKHealthStore`, la séance et les builders sont thread-safe ; l'état mutable est gardé par un verrou, d'où
/// `@unchecked Sendable`.
public final class HealthKitRunRecorder: NSObject, RunWorkoutRecording, @unchecked Sendable {
    let store: HKHealthStore
    private let lock = NSLock()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRates: AsyncStream<Double>.Continuation?
    /// La séance remise par `AppDelegate` après un crash, pas encore rattachée.
    private var adopted: HKWorkoutSession?

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    /// Les types qu'une course écrit : sans réponse pour l'un d'eux, la demande est à refaire.
    static var runTypes: [HKSampleType] {
        [HKWorkoutType.workoutType(), HKSeriesType.workoutRoute(), HKQuantityType(.distanceWalkingRunning)]
    }

    // MARK: - Autorisation

    public func writeAccess() async -> HealthWriteAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        // Une app qui écrivait déjà ses séances n'a jamais demandé le tracé ni la distance : la demande est refaite.
        if Self.runTypes.contains(where: { store.authorizationStatus(for: $0) == .notDetermined }) { return .notDetermined }
        return store.authorizationStatus(for: HKWorkoutType.workoutType()) == .sharingAuthorized ? .authorized : .denied
    }

    public func requestWriteAccess() async -> HealthWriteAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        // Une demande refusée ou interrompue n'empêche rien : l'état relu dit ce qui est permis.
        try? await store.requestAuthorization(toShare: HealthKitWorkoutWriter.shared, read: [])
        return await writeAccess()
    }

    // MARK: - Séance en direct

    public func start(sessionID: UUID, at date: Date) async throws -> AsyncStream<Double> {
        await discard()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        attach(session, builder: builder)
        let (stream, continuation) = AsyncStream.makeStream(of: Double.self)
        lock.withLock {
            self.session = session
            self.builder = builder
            heartRates = continuation
        }
        session.prepare()
        session.startActivity(with: date)
        do {
            try await builder.beginCollection(at: date)
        } catch {
            await discard()
            throw error
        }
        return stream
    }

    public func pause(at date: Date) async {
        lock.withLock { session }?.pause()
    }

    public func resume(at date: Date) async {
        lock.withLock { session }?.resume()
    }

    /// Ajoute la distance GPS et l'identifiant de la course, termine la séance puis écrit le tracé. Un échec termine quand même
    /// la séance : elle ne tourne jamais sans course.
    public func finish(_ entry: RunWorkoutEntry) async throws -> UUID? {
        guard let (session, builder) = takeLiveSession() else { return nil }
        do {
            if let distance = Self.distanceSample(entry) { try await builder.addSamples([distance]) }
            try await builder.addMetadata([HKMetadataKeyExternalUUID: entry.sessionID.uuidString])
            session.end()
            try await builder.endCollection(at: entry.end)
            guard let workout = try await builder.finishWorkout() else { throw WriteError.notSaved }
            await saveRoute(entry.route, for: workout)
            return workout.uuid
        } catch {
            session.end()
            builder.discardWorkout()
            throw error
        }
    }

    /// La course interrompue, sans séance vivante : le même entraînement, avec ses pauses en événements.
    public func save(_ entry: RunWorkoutEntry) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: entry.start)
        let events = Self.pauseEvents(entry)
        if !events.isEmpty { try await builder.addWorkoutEvents(events) }
        if let distance = Self.distanceSample(entry) { try await builder.addSamples([distance]) }
        try await builder.addMetadata([HKMetadataKeyExternalUUID: entry.sessionID.uuidString])
        try await builder.endCollection(at: entry.end)
        guard let workout = try await builder.finishWorkout() else { throw WriteError.notSaved }
        await saveRoute(entry.route, for: workout)
        return workout.uuid
    }

    /// Supprime l'entraînement écrit par Pulse, sa distance, son énergie et son tracé.
    public func deleteWorkout(id: UUID) async throws {
        guard store.authorizationStatus(for: HKWorkoutType.workoutType()) == .sharingAuthorized else { return }
        let ownWorkout = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObject(with: id), HKQuery.predicateForObjects(from: HKSource.default())
        ])
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(ownWorkout)], sortDescriptors: [])
        let writer = HealthKitWorkoutWriter(store: store)
        let associated: [HKSampleType] = [HKSeriesType.workoutRoute(), HKQuantityType(.distanceWalkingRunning),
                                          HKQuantityType(.activeEnergyBurned)]
        for workout in try await descriptor.result(for: store) {
            let fromPulse = NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForObjects(from: workout), HKQuery.predicateForObjects(from: HKSource.default())
            ])
            // Sans accès en écriture à un type, Pulse n'a rien pu y écrire.
            for type in associated where store.authorizationStatus(for: type) == .sharingAuthorized {
                try await writer.deleteObjects(of: type, matching: fromPulse)
            }
            try await store.delete(workout)
        }
    }

    public func discard() async {
        let (session, builder) = lock.withLock {
            let taken = (self.session ?? adopted, self.builder)
            self.session = nil
            self.builder = nil
            adopted = nil
            heartRates?.finish()
            heartRates = nil
            return taken
        }
        session?.end()
        builder?.discardWorkout()
    }

    // MARK: - Reprise après un crash

    /// La séance que `HKHealthStore.recoverActiveWorkoutSession` a rendue au lancement ; `recoverActiveSession()` la rattache.
    public func adopt(recoveredSession: HKWorkoutSession) {
        lock.withLock {
            if session == nil { adopted = recoveredSession }
        }
    }

    /// Rattache la séance remise par `adopt(recoveredSession:)`, ou à défaut celle que HealthKit garde encore : le builder est
    /// restauré par le système, mais la source de données est à recréer. La FC n'est plus livrée : son flux est perdu avec le
    /// processus.
    public func recoverActiveSession() async -> Bool {
        if let live = lock.withLock({ session }) { return Self.isAlive(live) }
        var recovered = lock.withLock {
            let taken = adopted
            adopted = nil
            return taken
        }
        if recovered == nil { recovered = try? await store.recoverActiveWorkoutSession() }
        guard let recovered, Self.isAlive(recovered) else { return false }
        let builder = recovered.associatedWorkoutBuilder()
        attach(recovered, builder: builder)
        return lock.withLock {
            // Une course démarrée pendant l'attente garde sa propre séance.
            guard session == nil else { return false }
            session = recovered
            self.builder = builder
            return true
        }
    }

    // MARK: - Interne

    enum WriteError: Error {
        case notSaved
    }

    private func attach(_ session: HKWorkoutSession, builder: HKLiveWorkoutBuilder) {
        let source = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: session.workoutConfiguration)
        source.disableCollection(for: HKQuantityType(.distanceWalkingRunning))
        builder.dataSource = source
        session.delegate = self
        builder.delegate = self
    }

    private func takeLiveSession() -> (HKWorkoutSession, HKLiveWorkoutBuilder)? {
        lock.withLock {
            guard let session, let builder else { return nil }
            self.session = nil
            self.builder = nil
            heartRates?.finish()
            heartRates = nil
            return (session, builder)
        }
    }

    private static func isAlive(_ session: HKWorkoutSession) -> Bool {
        session.state == .running || session.state == .paused
    }

    /// Un seul échantillon du début à la fin : la distance GPS filtrée, et elle seule.
    static func distanceSample(_ entry: RunWorkoutEntry) -> HKQuantitySample? {
        guard let meters = entry.distanceMeters, meters > 0, entry.end > entry.start else { return nil }
        return HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                quantity: HKQuantity(unit: .meter(), doubleValue: meters), start: entry.start, end: entry.end)
    }

    /// Une pause et sa reprise ; une pause encore ouverte à la fin n'a pas de reprise.
    static func pauseEvents(_ entry: RunWorkoutEntry) -> [HKWorkoutEvent] {
        entry.pauses.flatMap { pause -> [HKWorkoutEvent] in
            guard pause.start >= entry.start, pause.start < entry.end else { return [] }
            var events = [HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil)]
            if let end = pause.end, end < entry.end {
                events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: end, duration: 0), metadata: nil))
            }
            return events
        }
    }

    /// Le tracé est un plus : un échec laisse l'entraînement sans lui, sans rien signaler.
    private func saveRoute(_ points: [RunTrackPoint], for workout: HKWorkout) async {
        guard !points.isEmpty, store.authorizationStatus(for: HKSeriesType.workoutRoute()) == .sharingAuthorized else { return }
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        do {
            try await routeBuilder.insertRouteData(points.map(Self.location(from:)))
            _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
        } catch {
            routeBuilder.discard()
        }
    }

    static func location(from point: RunTrackPoint) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                   altitude: point.altitude ?? 0, horizontalAccuracy: point.horizontalAccuracy,
                   verticalAccuracy: point.altitude == nil ? -1 : point.verticalAccuracy ?? -1, timestamp: point.timestamp)
    }
}

// MARK: - Délégués

extension HealthKitRunRecorder: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                               from fromState: HKWorkoutSessionState, date: Date) {}

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {}

    /// La dernière FC collectée, livrée au flux de la course en cours ; un builder d'une séance passée est ignoré.
    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRate = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRate),
              let quantity = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity() else { return }
        let bpm = quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        let continuation = lock.withLock { builder === workoutBuilder ? heartRates : nil }
        continuation?.yield(bpm)
    }

    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
