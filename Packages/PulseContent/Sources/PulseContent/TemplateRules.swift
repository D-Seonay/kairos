import Foundation
import PulseDomain

/// Règles propres à un modèle de programme, évaluées dans l'ordre de la spec M2 §4.3.
enum TemplateRules {
    static func issues(for template: ProgramTemplate, in library: ContentLibrary) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let dayIDs = template.days.map(\.id)
        if Set(dayIDs).count != dayIDs.count {
            issues.append(ContentIssue(rule: .dayID, subject: template.id, message: "identifiants de jour en double"))
        }
        for day in template.days {
            issues += dayIssues(for: day, template: template, in: library)
        }
        issues += weekIssues(for: template, dayIDs: Set(dayIDs))
        return issues
    }

    private static func dayIssues(for day: TemplateDay, template: ProgramTemplate, in library: ContentLibrary) -> [ContentIssue] {
        let subject = "\(template.id)/\(day.id)"
        var issues: [ContentIssue] = []
        switch day.kind {
        case .run:
            let targets = [day.run?.targetMinutes != nil, day.run?.targetKm != nil].filter { $0 }.count
            if day.run == nil || targets != 1 || !day.exercises.isEmpty {
                issues.append(ContentIssue(rule: .runTarget, subject: subject,
                                           message: "jour de course : un seul objectif, pas d'exercice"))
            }
        case .strength:
            if !(1...10).contains(day.exercises.count) || day.run != nil {
                issues.append(ContentIssue(rule: .runTarget, subject: subject,
                                           message: "jour de musculation : 1 à 10 exercices, pas de course"))
            }
        }
        for exercise in day.exercises {
            issues += exerciseIssues(for: exercise, subject: "\(subject)/\(exercise.exercise)", in: library)
        }
        issues += supersetIssues(for: day, subject: subject)
        return issues
    }

    private static func exerciseIssues(for exercise: TemplateExercise, subject: String, in library: ContentLibrary) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        func add(_ rule: ContentRule, _ message: String) { issues.append(ContentIssue(rule: rule, subject: subject, message: message)) }
        if let found = library.exercise(id: exercise.exercise) {
            if found.retired { add(.templateExercise, "exercice retiré") }
        } else {
            add(.templateExercise, "exercice inconnu")
        }
        if !(1...6).contains(exercise.sets) { add(.templateSets, "1 à 6 séries") }
        if exercise.repsMin < 1 || exercise.repsMin > exercise.repsMax || exercise.repsMax > 30 { add(.templateReps, "1 ≤ min ≤ max ≤ 30") }
        if exercise.targetRPE < 6 || exercise.targetRPE > 10 || (exercise.targetRPE * 2).rounded() != exercise.targetRPE * 2 {
            add(.templateRPE, "RPE de 6 à 10 par pas de 0,5")
        }
        if !ContentValidator.allowedRests.contains(exercise.restSeconds) { add(.templateRest, "repos : 60, 90, 120 ou 180 s") }
        return issues
    }

    /// Un groupe de super set a exactement deux exercices, consécutifs.
    private static func supersetIssues(for day: TemplateDay, subject: String) -> [ContentIssue] {
        let groups = Dictionary(grouping: day.exercises.indices.filter { day.exercises[$0].supersetGroup != nil },
                                by: { day.exercises[$0].supersetGroup ?? 0 })
        return groups.keys.sorted().compactMap { group in
            let positions = groups[group] ?? []
            guard positions.count != 2 || positions[1] != positions[0] + 1 else { return nil }
            return ContentIssue(rule: .superset, subject: subject, message: "super set \(group) : deux exercices consécutifs attendus")
        }
    }

    private static func weekIssues(for template: ProgramTemplate, dayIDs: Set<String>) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let week = template.suggestedWeek
        let placed = week.compactMap { $0 }
        let unknown = placed.filter { !dayIDs.contains($0) }
        let missing = dayIDs.subtracting(placed)
        if week.count != 7 || !unknown.isEmpty || !missing.isEmpty {
            issues.append(ContentIssue(rule: .suggestedWeek, subject: template.id,
                                       message: "7 entrées, identifiants connus, chaque jour placé au moins une fois"))
        }
        if template.sessionsPerWeek != placed.count {
            issues.append(ContentIssue(rule: .sessionsPerWeek, subject: template.id,
                                       message: "sessionsPerWeek \(template.sessionsPerWeek) ≠ \(placed.count) jours placés"))
        }
        return issues
    }
}
