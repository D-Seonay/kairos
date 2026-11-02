import Foundation
import PulseDomain

/// Les exercices récemment pratiqués, pour les proposer en tête de la bibliothèque.
public enum RecentExercises {
    /// Les exercices des séances des `days` derniers jours, du plus récent au plus ancien, sans doublon.
    public static func references(in sessions: [WorkoutSession], now: Date, calendar: Calendar, days: Int = 30) -> [ExerciseReference] {
        guard let start = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }
        var seen: Set<ExerciseReference> = []
        var references: [ExerciseReference] = []
        for session in sessions.filter({ $0.startedAt >= start }).sorted(by: { $0.startedAt > $1.startedAt }) {
            for set in session.sets.sorted(by: { $0.order < $1.order }) where seen.insert(set.exercise).inserted {
                references.append(set.exercise)
            }
        }
        return references
    }
}
