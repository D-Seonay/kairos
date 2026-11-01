import Foundation
import PulseDomain

/// Les règles de validation du contenu (spec M2 §4.1 et §4.3).
public enum ContentRule: String, Sendable, CaseIterable {
    case exerciseCount
    case idFormat
    case duplicateID
    case nameMissing
    case primaryMuscles
    case secondaryMuscles
    case cues
    case mistakes
    case increment
    case rest
    case alternatives
    case riskAreas
    case patternPopulation
    case templateExercise
    case templateSets
    case templateReps
    case templateRPE
    case templateRest
    case superset
    case duplicateExerciseInDay
    case runTarget
    case suggestedWeek
    case sessionsPerWeek
    case dayID
}

/// Un problème de contenu, avec l'identifiant concerné et un message lisible.
public struct ContentIssue: Sendable, Equatable, CustomStringConvertible {
    public let rule: ContentRule
    public let subject: String
    public let message: String

    public init(rule: ContentRule, subject: String, message: String) {
        self.rule = rule
        self.subject = subject
        self.message = message
    }

    public var description: String { "[\(rule.rawValue)] \(subject) : \(message)" }
}

/// Valide une bibliothèque entière et renvoie tous les problèmes d'un coup.
public enum ContentValidator {
    static let expectedExerciseCount = 84
    static let minimumPerPattern = 4
    static let allowedIncrements: Set<Double> = [1.25, 2.5, 5]
    static let allowedRests: Set<Int> = [60, 90, 120, 180]
    static let maxTextLength = 90
    static func isValidID(_ id: String) -> Bool {
        id.wholeMatch(of: /^[a-z0-9]+(-[a-z0-9]+)*$/) != nil
    }

    public static func issues(in library: ContentLibrary) -> [ContentIssue] {
        issues(in: library, ignoring: [])
    }

    public static func issues(in library: ContentLibrary, ignoring: Set<ContentRule>) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        if library.exercises.count != expectedExerciseCount {
            issues.append(ContentIssue(rule: .exerciseCount, subject: "catalog",
                                       message: "\(library.exercises.count) exercices au lieu de \(expectedExerciseCount)"))
        }
        var seen = Set<String>()
        for exercise in library.exercises {
            if !seen.insert(exercise.id).inserted {
                issues.append(ContentIssue(rule: .duplicateID, subject: exercise.id, message: "identifiant en double"))
            }
            issues += ExerciseRules.issues(for: exercise, in: library)
        }
        issues += patternPopulationIssues(in: library)
        for template in library.programTemplates {
            issues += TemplateRules.issues(for: template, in: library)
        }
        return issues.filter { !ignoring.contains($0.rule) }
    }

    /// Chaque plan utilisé par au moins un exercice doit en avoir au moins 4 non retirés.
    private static func patternPopulationIssues(in library: ContentLibrary) -> [ContentIssue] {
        let active = Dictionary(grouping: library.activeExercises, by: \.pattern)
        return MovementPattern.allCases.compactMap { pattern in
            guard library.exercises.contains(where: { $0.pattern == pattern }) else { return nil }
            let count = active[pattern]?.count ?? 0
            guard count < minimumPerPattern else { return nil }
            return ContentIssue(rule: .patternPopulation, subject: pattern.rawValue,
                                message: "\(count) exercice(s), minimum \(minimumPerPattern)")
        }
    }
}
