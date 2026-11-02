import Foundation
import PulseContent
import PulseDomain

/// Recherche, filtres et ordre de la bibliothèque d'exercices.
public enum ExerciseBrowser {
    /// Les exercices dont le nom français ou anglais contient chaque mot de `query` (sans tenir compte de la casse ni des accents),
    /// du groupe et du matériel demandés. Les récents d'abord, dans l'ordre de `recent`, puis l'ordre alphabétique français.
    public static func results(_ exercises: [ExerciseInfo], query: String, group: MuscleGroup?, equipment: Equipment?,
                               recent: [ExerciseReference]) -> [ExerciseInfo] {
        let words = SearchText.fold(query).split(separator: " ").map(String.init)
        let matches = exercises.filter { exercise in
            (group == nil || exercise.group == group) && (equipment == nil || exercise.equipment == equipment)
                && matches(exercise, words: words)
        }
        let rank = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return matches.sorted { lhs, rhs in
            switch (rank[lhs.reference], rank[rhs.reference]) {
            case (let left?, let right?): left < right
            case (.some, nil): true
            case (nil, .some): false
            case (nil, nil): lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private static func matches(_ exercise: ExerciseInfo, words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let names = [exercise.name, exercise.englishName].compactMap { $0 }.map(SearchText.fold)
        return words.allSatisfy { word in names.contains { $0.contains(word) } }
    }
}
