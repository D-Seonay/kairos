import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Les entraînements d'Apple Santé autres que course et vélo (natation, HIIT, sports, musculation d'une autre app…), lus dans le
/// cache local à chaque calcul : ils comptent dans la charge et s'affichent dans l'assiduité et le mois, sans jamais devenir des
/// séances. Ne comptent pas, pour ne pas compter deux fois : ceux que Pulse a lui-même écrits dans Apple Santé, et ceux qui
/// chevauchent une séance enregistrée (la montre lancée pendant une séance Pulse, une séance Hevy importée).
public struct HealthActivities: Sendable {
    private let cache: any HealthSampleCache
    private let profiles: any ProfileRepository
    private let calendar: Calendar
    private let ownBundleIdentifier: String?

    public init(cache: any HealthSampleCache, profiles: any ProfileRepository, calendar: Calendar, ownBundleIdentifier: String?) {
        self.cache = cache
        self.profiles = profiles
        self.calendar = calendar
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    /// La charge des entraînements commencés entre `from` et `to`, hors ceux qui chevauchent une des `sessions` ; aucune si le
    /// cache est illisible.
    public func loadSessions(from: Date, to: Date, excluding sessions: [WorkoutSession]) async -> [LoadSession] {
        let samples = await samples(from: from, to: to)
        guard !samples.isEmpty else { return [] }
        let birthDate = (try? await profiles.load())?.birthDate
        return Self.loadSessions(of: samples, excluding: sessions, ownBundleIdentifier: ownBundleIdentifier, birthDate: birthDate,
                                 calendar: calendar)
    }

    /// Les débuts des entraînements commencés entre `from` et `to`, dans l'ordre.
    public func starts(from: Date, to: Date) async -> [Date] {
        await samples(from: from, to: to).filter { Self.isCounted($0, ownBundleIdentifier: ownBundleIdentifier) }
            .map(\.start).sorted()
    }

    private func samples(from: Date, to: Date) async -> [CachedHealthSample] {
        (try? await cache.samples(kind: .otherWorkout, from: from, to: to)) ?? []
    }

    // MARK: - Pur

    /// Minutes × RPE : le RPE vient de la fréquence cardiaque moyenne quand elle existe (`EstimatedRPE`), sinon de la famille.
    /// Un entraînement sans durée, écrit par Pulse, ou qui chevauche une séance terminée ou abandonnée de `sessions`, ne compte
    /// pas.
    public static func loadSessions(of samples: [CachedHealthSample], excluding sessions: [WorkoutSession] = [],
                                    ownBundleIdentifier: String?, birthDate: Date?, calendar: Calendar) -> [LoadSession] {
        let taken = sessions.filter { $0.status == .completed || $0.status == .abandoned }.map(interval)
        return samples.filter { isCounted($0, ownBundleIdentifier: ownBundleIdentifier) }.compactMap { sample in
            let minutes = sample.durationMinutes ?? sample.end.timeIntervalSince(sample.start) / 60
            guard minutes > 0, !taken.contains(where: { overlaps(sample, $0) }) else { return nil }
            let maxHeartRate = EstimatedRPE.maxHeartRate(birthDate: birthDate, at: sample.start, calendar: calendar)
            let rpe = EstimatedRPE.rpe(averageHeartRate: sample.averageHeartRate, maxHeartRate: maxHeartRate)
                ?? WorkoutFamily(storedValue: sample.value).defaultRPE
            return LoadSession(date: sample.start, minutes: minutes, rpe: rpe)
        }
    }

    static func isCounted(_ sample: CachedHealthSample, ownBundleIdentifier: String?) -> Bool {
        ownBundleIdentifier == nil || sample.sourceBundleID != ownBundleIdentifier
    }

    /// Le temps d'une séance : de son début à sa fin, sinon à son début plus sa durée.
    private static func interval(of session: WorkoutSession) -> (start: Date, end: Date) {
        let end = session.endedAt ?? session.startedAt.addingTimeInterval((session.durationMinutes ?? 0) * 60)
        return (session.startedAt, max(end, session.startedAt))
    }

    private static func overlaps(_ sample: CachedHealthSample, _ session: (start: Date, end: Date)) -> Bool {
        sample.start < session.end && session.start < sample.end
    }
}
