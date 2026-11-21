import Foundation
import PulseDomain

/// Lit les courses et les vélos d'Apple Santé dans le cache local, puis les aligne sur les séances (spec M6 §3) : un
/// entraînement nouveau devient une séance `appleHealth`, un entraînement effacé dans Apple Santé emporte sa séance.
public struct WorkoutHistory: Sendable {
    /// La fenêtre lue : un an, pour que les statistiques et les records de course voient les sorties anciennes (spec M7 §6).
    public static let historyDays = 365

    private let source: any HealthWorkoutSource
    private let cache: any HealthSampleCache
    private let workouts: any WorkoutRepository
    private let profiles: any ProfileRepository
    private let windows: any HealthReadWindowStore
    private let calendar: Calendar

    public init(source: any HealthWorkoutSource, cache: any HealthSampleCache, workouts: any WorkoutRepository,
                profiles: any ProfileRepository, windows: any HealthReadWindowStore, calendar: Calendar) {
        self.source = source
        self.cache = cache
        self.workouts = workouts
        self.profiles = profiles
        self.windows = windows
        self.calendar = calendar
    }

    /// Un type à la fois : un type dont la lecture ou l'écriture du cache échoue garde ses séances telles quelles. Rend vrai si
    /// une séance a été ajoutée, modifiée ou supprimée.
    @discardableResult
    public func refresh(now: Date) async -> Bool {
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: calendar.startOfDay(for: now)) ?? now
        let birthDate = (try? await profiles.load())?.birthDate
        var changed = false
        for signal in WorkoutSignal.allCases {
            guard await sync(signal, from: start, fetchedAt: now) else { continue }
            changed = await align(signal, from: start, now: now, birthDate: birthDate) || changed
        }
        return changed
    }

    private func sync(_ signal: WorkoutSignal, from start: Date, fetchedAt: Date) async -> Bool {
        // Une fenêtre lue plus étroite que celle d'aujourd'hui (60 jours avant M7, ou rien) : l'ancre est ignorée, la lecture est
        // complète et le cache remplace le type. La fenêtre n'est retenue qu'une fois le cache écrit, donc un échec est retenté.
        let widened = (windows.days(for: signal.kind) ?? 0) >= Self.historyDays
        let anchor = widened ? try? await cache.anchor(for: signal.kind) : nil
        do {
            var changes = try await source.workoutChanges(of: signal, since: anchor, from: start)
            changes.added = changes.added.map { sample in
                var stamped = sample
                stamped.fetchedAt = fetchedAt
                return stamped
            }
            try await cache.apply(changes)
            windows.save(days: Self.historyDays, for: signal.kind)
            return true
        } catch {
            return false
        }
    }

    /// Ajoute, met à jour ou supprime les séances du type commencées dans la fenêtre pour qu'elles suivent le cache.
    private func align(_ signal: WorkoutSignal, from start: Date, now: Date, birthDate: Date?) async -> Bool {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        guard let samples = try? await cache.samples(kind: signal.kind, from: start, to: end),
              let sessions = try? await workouts.sessions(from: start, to: end) else { return false }
        let imported = sessions.filter { $0.source == .appleHealth && $0.kind == signal.sessionKind }
        var byUUID = [String: WorkoutSession]()
        for session in imported {
            if let uuid = session.healthKitUUID { byUUID[uuid] = session }
        }
        var changed = false
        var seen = Set<String>()
        for sample in samples {
            guard let uuid = sample.healthKitUUID, seen.insert(uuid).inserted else { continue }
            let maxHeartRate = EstimatedRPE.maxHeartRate(birthDate: birthDate, at: sample.start, calendar: calendar)
            let session = Self.session(from: sample, signal: signal, existing: byUUID[uuid], maxHeartRate: maxHeartRate, now: now)
            guard session != byUUID[uuid] else { continue }
            if (try? await workouts.save(session)) != nil { changed = true }
        }
        for session in imported where session.healthKitUUID.map({ !seen.contains($0) }) ?? true {
            if (try? await workouts.delete(id: session.id)) != nil { changed = true }
        }
        return changed
    }

    /// La séance d'un entraînement lu. Une séance existante garde son identifiant, sa création, son RPE et sa note saisis
    /// dans Pulse ; seuls les champs lus d'Apple Santé suivent l'entraînement.
    static func session(from sample: CachedHealthSample, signal: WorkoutSignal, existing: WorkoutSession?, maxHeartRate: Double,
                        now: Date) -> WorkoutSession {
        var session = existing ?? WorkoutSession(
            startedAt: sample.start, kind: signal.sessionKind, source: .appleHealth, status: .completed,
            title: title(of: signal), createdAt: now, updatedAt: now)
        let previous = session
        session.startedAt = sample.start
        session.endedAt = sample.end
        session.durationMinutes = sample.durationMinutes ?? sample.end.timeIntervalSince(sample.start) / 60
        session.distanceMeters = sample.distanceMeters
        session.averageHeartRate = sample.averageHeartRate
        session.estimatedRPE = EstimatedRPE.rpe(averageHeartRate: sample.averageHeartRate, maxHeartRate: maxHeartRate)
        session.healthKitUUID = sample.healthKitUUID
        if existing != nil, session != previous { session.updatedAt = now }
        return session
    }

    static func title(of signal: WorkoutSignal) -> String {
        switch signal {
        case .run: String(localized: "Course", bundle: .module)
        case .ride: String(localized: "Vélo", bundle: .module)
        }
    }
}
