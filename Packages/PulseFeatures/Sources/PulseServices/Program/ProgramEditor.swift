import Foundation
import PulseDomain

/// Modifie un programme sans l'enregistrer : chaque fonction rend une copie dont `updatedAt` vaut `now`.
/// `sessionsPerWeek` est toujours recalculé depuis la semaine type.
public enum ProgramEditor {
    public static func emptyProgram(name: String, now: Date) -> Program {
        Program(name: name, sessionsPerWeek: 0, weekLayout: [UUID?](repeating: nil, count: Weekday.allCases.count),
                days: [], createdAt: now, updatedAt: now)
    }

    /// Place `dayID` (ou un repos, si `nil`) sur `weekday`. Un jour inconnu du programme laisse tout inchangé.
    public static func assign(_ dayID: UUID?, to weekday: Weekday, in program: Program, now: Date) -> Program {
        if let dayID, !program.days.contains(where: { $0.id == dayID }) { return program }
        var result = program
        result.weekLayout = week(of: program)
        result.weekLayout[weekday.index] = dayID
        return finished(result, now: now)
    }

    /// Ajoute un jour de musculation en fin de programme.
    public static func addDay(named name: String, exercises: [RoutineExercise], to program: Program,
                              now: Date) -> (program: Program, dayID: UUID) {
        var result = program
        let day = RoutineEditor.normalized(RoutineDay(order: program.days.count, name: name, kind: .strength, exercises: exercises))
        result.days.append(day)
        return (finished(result, now: now), day.id)
    }

    /// Remplace le jour de même identifiant, à sa place. Un jour inconnu laisse tout inchangé.
    public static func replaceDay(_ day: RoutineDay, in program: Program, now: Date) -> Program {
        guard let index = program.days.firstIndex(where: { $0.id == day.id }) else { return program }
        var result = program
        result.days[index] = RoutineEditor.normalized(day)
        return finished(result, now: now)
    }

    /// Retire le jour du programme et de la semaine type, puis renumérote les autres.
    public static func removeDay(id: UUID, from program: Program, now: Date) -> Program {
        var result = program
        result.days.removeAll { $0.id == id }
        result.weekLayout = week(of: program).map { $0 == id ? nil : $0 }
        return finished(result, now: now)
    }

    /// Copie le jour en fin de programme, nommé « … (copie) » et avec de nouveaux identifiants.
    public static func duplicateDay(id: UUID, in program: Program, now: Date) -> Program {
        guard let source = program.days.first(where: { $0.id == id }) else { return program }
        var copy = source
        copy.id = UUID()
        copy.name = String(localized: "\(source.name) (copie)", bundle: .module)
        copy.exercises = source.exercises.map { exercise in
            var duplicate = exercise
            duplicate.id = UUID()
            return duplicate
        }
        var result = program
        result.days.append(copy)
        return finished(result, now: now)
    }

    /// Renomme le programme ; un nom vide laisse l'ancien.
    public static func rename(_ program: Program, to name: String, now: Date) -> Program {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = program
        if !trimmed.isEmpty { result.name = trimmed }
        return finished(result, now: now)
    }

    /// La semaine type ramenée à 7 entrées, lundi à dimanche.
    private static func week(of program: Program) -> [UUID?] {
        let count = Weekday.allCases.count
        return Array((program.weekLayout + [UUID?](repeating: nil, count: count)).prefix(count))
    }

    private static func finished(_ program: Program, now: Date) -> Program {
        var result = program
        for index in result.days.indices { result.days[index].order = index }
        result.weekLayout = week(of: result)
        result.sessionsPerWeek = result.weekLayout.compactMap { $0 }.count
        result.updatedAt = now
        return result
    }
}
