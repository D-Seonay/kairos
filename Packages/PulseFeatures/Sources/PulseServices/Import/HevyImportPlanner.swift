import Foundation
import PulseContent
import PulseDomain

/// Un nom d'exercice de l'export, avec ce qu'il devient à l'import.
public struct HevyNameSummary: Sendable, Equatable, Identifiable {
    public let name: String
    /// Le nombre de séances à importer qui le contiennent.
    public let sessionCount: Int
    /// Le nombre de séries à importer qui le portent.
    public let setCount: Int
    /// Toutes ses séries n'ont ni charge ni répétitions mais une durée ou une distance.
    public let isCardio: Bool
    /// Le nom figure dans la table de correspondance du contenu (indépendamment du choix retenu).
    public let isSure: Bool
    public let choice: HevyMappingChoice

    public var id: String { name }
}

/// Ce que l'import va faire : séances nouvelles, doublons écartés, cardio, et le choix proposé pour chaque nom d'exercice.
public struct HevyImportPreview: Sendable, Equatable {
    public let newWorkouts: [HevyWorkout]
    public let duplicateCount: Int
    /// Les lignes de cardio des séances nouvelles.
    public let cardioSetCount: Int
    /// Du début de la première séance nouvelle au début de la dernière ; `nil` sans séance nouvelle.
    public let period: ClosedRange<Date>?
    public let names: [HevyNameSummary]
}

public enum HevyImportPlanner {
    public static func preview(rows: [HevyRow], existing: [WorkoutSession], library: ContentLibrary, userExercises: [UserExercise],
                               remembered: [String: HevyMappingChoice]) throws -> HevyImportPreview {
        guard !rows.isEmpty else { throw HevyImportError.empty }
        let imported = Set(existing.filter { $0.source == .hevy }.map { SessionKey(title: $0.title, minute: minute($0.startedAt)) })
        let workouts = HevyWorkouts.group(rows)
        let fresh = workouts.filter { !imported.contains(SessionKey(title: $0.title, minute: minute($0.startedAt))) }
        let resolver = Resolver(library: library, userExercises: userExercises, remembered: remembered)
        let names = summaries(of: fresh, resolver: resolver)
        let cardioNames = Set(names.filter(\.isCardio).map(\.name))
        let starts = fresh.map(\.startedAt)
        return HevyImportPreview(
            newWorkouts: fresh, duplicateCount: workouts.count - fresh.count,
            cardioSetCount: fresh.reduce(0) { total, workout in
                total + workout.exercises.filter { cardioNames.contains($0.name) }.reduce(0) { $0 + $1.sets.count }
            },
            period: starts.min().flatMap { first in starts.max().map { first...$0 } }, names: names)
    }

    private struct SessionKey: Hashable {
        let title: String
        let minute: Int
    }

    private static func minute(_ date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 60).rounded(.down))
    }

    /// Une ligne de cardio : ni charge ni répétitions, mais une durée ou une distance.
    private static func isCardioRow(_ row: HevyRow) -> Bool {
        (row.weightKg ?? 0) <= 0 && (row.reps ?? 0) <= 0 && ((row.durationSeconds ?? 0) > 0 || (row.distanceKm ?? 0) > 0)
    }

    private static func summaries(of workouts: [HevyWorkout], resolver: Resolver) -> [HevyNameSummary] {
        var sets: [String: [HevyRow]] = [:]
        var sessions: [String: Int] = [:]
        for workout in workouts {
            for name in Set(workout.exercises.map(\.name)) { sessions[name, default: 0] += 1 }
            for block in workout.exercises { sets[block.name, default: []].append(contentsOf: block.sets) }
        }
        return sets.map { name, rows in
            let isCardio = rows.allSatisfy(isCardioRow)
            let sure = resolver.sureContentID(forHevyName: name)
            return HevyNameSummary(name: name, sessionCount: sessions[name] ?? 0, setCount: rows.count, isCardio: isCardio,
                                   isSure: sure != nil,
                                   choice: resolver.choice(for: name, sureContentID: sure, isCardio: isCardio))
        }
        .sorted { lhs, rhs in
            if lhs.sessionCount != rhs.sessionCount { return lhs.sessionCount > rhs.sessionCount }
            let (left, right) = (SearchText.fold(lhs.name), SearchText.fold(rhs.name))
            return left == right ? lhs.name < rhs.name : left < right
        }
    }

    private struct Resolver {
        let library: ContentLibrary
        let userExercises: [UserExercise]
        let remembered: [String: HevyMappingChoice]

        /// L'exercice du contenu que la table associe au nom, s'il existe et n'est pas retiré.
        func sureContentID(forHevyName name: String) -> String? {
            library.exerciseID(forHevyName: name).flatMap { isLive(contentID: $0) ? $0 : nil }
        }

        /// Dans l'ordre : le choix mémorisé s'il désigne encore un exercice, la correspondance sûre, l'exercice perso de même nom
        /// replié, `.ignore` pour le cardio, sinon la création d'un exercice deviné.
        func choice(for name: String, sureContentID: String?, isCardio: Bool) -> HevyMappingChoice {
            if let choice = remembered[name], stands(choice) { return choice }
            if let sureContentID { return .content(id: sureContentID) }
            let folded = SearchText.fold(name)
            if let user = userExercises.first(where: { !$0.isArchived && SearchText.fold($0.name) == folded }) {
                return .user(id: user.id)
            }
            return isCardio ? .ignore : .create(HevyNameGuesser.draft(for: name))
        }

        private func isLive(contentID: String) -> Bool {
            library.exercise(id: contentID).map { !$0.retired } ?? false
        }

        /// Un exercice perso archivé compte : il existe encore.
        private func stands(_ choice: HevyMappingChoice) -> Bool {
            switch choice {
            case .content(let id): isLive(contentID: id)
            case .user(let id): userExercises.contains { $0.id == id }
            case .create, .ignore: true
            }
        }
    }
}
