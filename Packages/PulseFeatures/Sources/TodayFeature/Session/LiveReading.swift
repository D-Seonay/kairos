import Foundation
import PulseDomain
import PulseServices

/// Ce que l'accueil lit en plus du score pour parler de la séance en direct : la séance en cours, le bilan de celle du jour, et
/// l'historique et les réglages des exercices du jour, qui permettent de dire les hausses de charge sans rien écrire.
struct LiveReading {
    var inProgressTitle: String?
    var done: DoneCard?
    var history: [ExerciseReference: [WorkoutSet]] = [:]
    var settings: [ExerciseReference: ExerciseSettings] = [:]
}

extension TodayEnvironment {
    /// Relit la séance en cours, le bilan du jour et l'historique des exercices de `plannedDay`. Une lecture qui échoue garde
    /// la valeur de `previous`.
    func readLive(plannedDay: PlannedDay, previous: LiveReading) async -> LiveReading {
        var reading = previous
        reading.inProgressTitle = await activeSession.current()?.title
        let start = calendar.startOfDay(for: now())
        if let end = calendar.date(byAdding: .day, value: 1, to: start),
           let today = try? await workouts.sessions(from: start, to: end) {
            reading.done = DoneCard.latest(in: today)
        }
        reading.history = [:]
        reading.settings = [:]
        for reference in plannedDay.routineDay?.exercises.map(\.exercise) ?? [] {
            reading.history[reference] = (try? await workouts.lastSets(for: reference)) ?? previous.history[reference]
            reading.settings[reference] = (try? await exerciseSettings.settings(for: reference)) ?? previous.settings[reference]
        }
        return reading
    }
}
