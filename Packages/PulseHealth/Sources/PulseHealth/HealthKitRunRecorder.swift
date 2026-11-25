import CoreLocation
import Foundation
import HealthKit
import os
import PulseDomain

/// La séance HealthKit d'une course (spec V2a) : une `HKWorkoutSession` de course en extérieur et son builder en direct, qui
/// livre la FC. La distance du podomètre n'est pas collectée : seule la distance GPS filtrée de Pulse arrive dans Santé, avec
/// le tracé. `HKHealthStore`, la séance et les builders sont thread-safe ; l'état mutable est gardé par un verrou, d'où
/// `@unchecked Sendable`.
public final class HealthKitRunRecorder: NSObject, RunWorkoutRecording, @unchecked Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "fr.seonay.pulse", category: "run")

    let store: HKHealthStore
    private let lock = NSLock()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRates: AsyncStream<Double>.Continuation?
    /// La reprise en cours après un crash : `AppDelegate` et l'offre de reprise la partagent, pour un seul appel à HealthKit.
    private var recovery: Task<Bool, Never>?

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
    ///
    /// Sans entraînement ni erreur (iPhone verrouillé), HealthKit garde l'entraînement et l'écrit au déverrouillage : il n'est pas
    /// jeté, et `RunWorkoutWriteDeferred` empêche le repli de l'écrire une seconde fois. Le tracé est alors perdu.
    public func finish(_ entry: RunWorkoutEntry) async throws -> UUID? {
        guard let (session, builder) = takeLiveSession() else { return nil }
        let finished: HKWorkout?
        do {
            if let distance = distanceSample(entry) { try await builder.addSamples([distance]) }
            try await builder.addMetadata([HKMetadataKeyExternalUUID: entry.sessionID.uuidString])
            session.end()
            try await builder.endCollection(at: entry.end)
            finished = try await builder.finishWorkout()
        } catch {
            session.end()
            builder.discardWorkout()
            throw error
        }
        guard let workout = finished else { throw RunWorkoutWriteDeferred() }
        await saveRoute(entry.route, for: workout)
        return workout.uuid
    }

    /// La course interrompue, sans séance vivante : le même entraînement, avec ses pauses en événements. Un entraînement déjà
    /// écrit pour la même course (fin laissée à HealthKit puis écrite au déverrouillage) est rendu au lieu d'en écrire un second.
    public func save(_ entry: RunWorkoutEntry) async throws -> UUID {
        if let existing = await savedWorkout(for: entry.sessionID) { return existing }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: entry.start)
        let events = Self.pauseEvents(entry)
        if !events.isEmpty { try await builder.addWorkoutEvents(events) }
        if let distance = distanceSample(entry) { try await builder.addSamples([distance]) }
        try await builder.addMetadata([HKMetadataKeyExternalUUID: entry.sessionID.uuidString])
        try await builder.endCollection(at: entry.end)
        guard let workout = try await builder.finishWorkout() else { throw RunWorkoutWriteDeferred() }
        await saveRoute(entry.route, for: workout)
        return workout.uuid
    }

    /// L'entraînement que Pulse a déjà écrit pour la course `sessionID`, repéré par son identifiant externe ; `nil` si la lecture
    /// échoue (iPhone verrouillé) ou ne trouve rien.
    private func savedWorkout(for sessionID: UUID) async -> UUID? {
        let ownWorkout = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [sessionID.uuidString]),
            HKQuery.predicateForObjects(from: HKSource.default())
        ])
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(ownWorkout)], sortDescriptors: [], limit: 1)
        return (try? await descriptor.result(for: store))?.first?.uuid
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

    /// Une reprise en cours est attendue d'abord : la séance qu'elle rattache est terminée avec le reste.
    public func discard() async {
        if let pending = lock.withLock({ recovery }) { _ = await pending.value }
        let (session, builder) = lock.withLock {
            let taken = (self.session, self.builder)
            self.session = nil
            self.builder = nil
            heartRates?.finish()
            heartRates = nil
            return taken
        }
        session?.end()
        builder?.discardWorkout()
    }

    // MARK: - Reprise après un crash

    /// Rattache la séance que HealthKit garde encore après un crash : le builder est restauré par le système, mais la source de
    /// données est à recréer. La FC n'est plus livrée : son flux est perdu avec le processus. Les appels simultanés (relance par
    /// le système depuis `AppDelegate`, offre de reprise) partagent la même reprise.
    public func recoverActiveSession() async -> Bool {
        let task = lock.withLock {
            if let recovery { return recovery }
            let task = Task { await self.performRecovery() }
            recovery = task
            return task
        }
        let isRecording = await task.value
        lock.withLock { if recovery == task { recovery = nil } }
        return isRecording
    }

    private func performRecovery() async -> Bool {
        if let live = lock.withLock({ session }) { return Self.isAlive(live) }
        let recovered: HKWorkoutSession?
        do {
            recovered = try await store.recoverActiveWorkoutSession()
        } catch {
            Self.logger.error("Reprise de la séance de course impossible : \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard let recovered, Self.isAlive(recovered) else { return false }
        let builder = recovered.associatedWorkoutBuilder()
        attach(recovered, builder: builder)
        let isAttached = lock.withLock {
            // Une course démarrée pendant l'attente garde sa propre séance.
            guard session == nil else { return false }
            session = recovered
            self.builder = builder
            return true
        }
        // La séance rendue sans course pour la mener est terminée : elle ne tourne jamais seule.
        if !isAttached { recovered.end() }
        return isAttached
    }

    // MARK: - Interne

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

    /// Un seul échantillon du début à la fin : la distance GPS filtrée, et elle seule. Sans accès en écriture à la distance,
    /// l'entraînement part sans elle plutôt que d'échouer.
    private func distanceSample(_ entry: RunWorkoutEntry) -> HKQuantitySample? {
        guard store.authorizationStatus(for: HKQuantityType(.distanceWalkingRunning)) == .sharingAuthorized,
              let meters = entry.distanceMeters, meters > 0, entry.end > entry.start else { return nil }
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
    /// La séance de la course terminée hors de Pulse (par le système) : le flux de FC se termine. La fin de la course écrit
    /// alors l'entraînement sans séance vivante si la séance ne peut plus être terminée.
    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                               from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended else { return }
        endHeartRates(of: workoutSession)
    }

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Self.logger.error("Séance de course en échec : \(error.localizedDescription, privacy: .public)")
        endHeartRates(of: workoutSession)
    }

    /// Le flux de FC de la course en cours, si `workoutSession` est bien sa séance ; une séance passée est ignorée.
    private func endHeartRates(of workoutSession: HKWorkoutSession) {
        let continuation = lock.withLock { () -> AsyncStream<Double>.Continuation? in
            guard session === workoutSession else { return nil }
            let taken = heartRates
            heartRates = nil
            return taken
        }
        continuation?.finish()
    }

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
