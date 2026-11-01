import Foundation
import PulseDomain

/// Règles propres à un exercice, évaluées dans l'ordre de la spec M2 §4.1.
enum ExerciseRules {
    static func issues(for exercise: Exercise, in library: ContentLibrary) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        func add(_ rule: ContentRule, _ message: String) {
            issues.append(ContentIssue(rule: rule, subject: exercise.id, message: message))
        }
        if !ContentValidator.isValidID(exercise.id) {
            add(.idFormat, "identifiant attendu en kebab-case ASCII")
        }
        if exercise.name.fr.trimmingCharacters(in: .whitespaces).isEmpty
            || (exercise.name.en ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            add(.nameMissing, "nom fr et en obligatoires")
        }
        if !(1...3).contains(exercise.primaryMuscles.count) || Set(exercise.primaryMuscles).count != exercise.primaryMuscles.count {
            add(.primaryMuscles, "1 à 3 muscles principaux sans doublon")
        }
        if exercise.secondaryMuscles.count > 4 || !Set(exercise.secondaryMuscles).isDisjoint(with: exercise.primaryMuscles) {
            add(.secondaryMuscles, "0 à 4 stabilisateurs, disjoints des principaux")
        }
        if exercise.cues.fr.count != 3 || exercise.cues.fr.contains(where: { $0.count > ContentValidator.maxTextLength }) {
            add(.cues, "exactement 3 consignes de 90 caractères au plus")
        }
        if !(2...3).contains(exercise.mistakes.fr.count)
            || exercise.mistakes.fr.contains(where: { $0.count > ContentValidator.maxTextLength }) {
            add(.mistakes, "2 ou 3 erreurs de 90 caractères au plus")
        }
        if !ContentValidator.allowedIncrements.contains(exercise.defaultIncrementKg) {
            add(.increment, "incrément attendu : 1,25, 2,5 ou 5 kg")
        }
        if !ContentValidator.allowedRests.contains(exercise.defaultRestSeconds) {
            add(.rest, "repos attendu : 60, 90, 120 ou 180 s")
        }
        issues += alternativeIssues(for: exercise, in: library)
        return issues
    }

    private static func alternativeIssues(for exercise: Exercise, in library: ContentLibrary) -> [ContentIssue] {
        var messages: [String] = []
        if exercise.alternatives.count != 3 { messages.append("exactement 3 alternatives attendues") }
        if exercise.alternatives.contains(exercise.id) { messages.append("se cite lui-même") }
        if Set(exercise.alternatives).count != exercise.alternatives.count { messages.append("alternatives en double") }
        let resolved = exercise.alternatives.map { ($0, library.exercise(id: $0)) }
        let unknown = resolved.filter { $0.1 == nil }.map(\.0)
        if !unknown.isEmpty { messages.append("alternatives inconnues : \(unknown.joined(separator: ", "))") }
        let otherPattern = resolved.compactMap { id, found in found.flatMap { $0.pattern == exercise.pattern ? nil : id } }
        if !otherPattern.isEmpty { messages.append("alternatives d'un autre plan : \(otherPattern.joined(separator: ", "))") }
        return messages.map { ContentIssue(rule: .alternatives, subject: exercise.id, message: $0) }
    }
}
