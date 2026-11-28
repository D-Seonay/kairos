import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les textes des routines et de leurs exercices, de la correction d'une séance et de la période d'un import.
extension TrainText {
    // MARK: - Routines

    /// « 5 exercices · ~ 65 min · lundi, jeudi » ; « Sortie facile · 45 min · hors semaine type » pour une course.
    static func routineSubtitle(_ routine: RoutineSummary) -> String {
        var parts: [String] = []
        if routine.day.kind == .run {
            parts.append(runSummary(routine.day))
        } else {
            parts.append(exercises(routine.exerciseCount))
            parts.append(String(localized: "~ \(routine.estimatedMinutes) min", bundle: .module))
        }
        parts.append(days(of: routine))
        return parts.joined(separator: " · ")
    }

    /// « 5 exercices, environ 1 heure 5 minutes, lundi, jeudi » : la même ligne sans « ~ » ni « · », avec des durées en mots.
    static func routineSubtitleSpoken(_ routine: RoutineSummary) -> String {
        var parts: [String] = []
        if routine.day.kind == .run {
            parts.append(runSummarySpoken(routine.day))
        } else {
            parts.append(exercises(routine.exerciseCount))
            parts.append(approximateMinutes(routine.estimatedMinutes))
        }
        parts.append(days(of: routine))
        return parts.joined(separator: ", ")
    }

    /// « Sortie facile · 40 min » : le type et l'objectif d'une course, sans ses jours. Une course qui porte le nom de son type
    /// (celles de l'éditeur) ne le répète pas sous son titre : « 40 min », ou « Course » sans objectif.
    static func runSummary(_ day: RoutineDay) -> String {
        runParts(day, goal: runGoalValue(RunDayEditor.goal(of: day))).joined(separator: " · ")
    }

    /// « Sortie facile, 40 minutes » : `runSummary` dit en mots.
    static func runSummarySpoken(_ day: RoutineDay) -> String {
        runParts(day, goal: runGoalSpoken(RunDayEditor.goal(of: day))).joined(separator: ", ")
    }

    /// « Sortie longue · 60 min » : une course dans le menu de la semaine, où deux sorties du même type se distinguent par
    /// leur objectif.
    static func runMenuTitle(_ day: RoutineDay) -> String {
        ([day.name] + [runGoalValue(RunDayEditor.goal(of: day))].compactMap { $0 }).joined(separator: " · ")
    }

    /// « 45 min », « 7,5 km » ; `nil` sans objectif.
    static func runGoalValue(_ goal: RunGoal) -> String? {
        switch goal {
        case .none:
            return nil
        case .minutes(let minutes):
            return String(localized: "\(minutes) min", bundle: .module)
        case .kilometres(let kilometres):
            return PulseUnits.current.distance(kilometres: kilometres, maxFractionDigits: 1, grouped: true)
        }
    }

    /// « 45 minutes », « 7,5 kilomètres » ; `nil` sans objectif.
    static func runGoalSpoken(_ goal: RunGoal) -> String? {
        switch goal {
        case .none: nil
        case .minutes(let minutes): PulseSpoken.duration(seconds: minutes * 60)
        case .kilometres(let kilometres): PulseSpoken.kilometres(kilometres)
        }
    }

    /// « environ 55 minutes », « environ 1 heure 5 minutes » : la durée estimée d'une séance.
    static func approximateMinutes(_ minutes: Int) -> String {
        String(localized: "environ \(PulseSpoken.duration(seconds: minutes * 60))", bundle: .module)
    }

    /// « 5 exercices · ~ 55 min » : le résumé de l'éditeur d'une routine.
    static func editorSummary(exerciseCount: Int, estimatedMinutes: Int) -> String {
        [exercises(exerciseCount), String(localized: "~ \(estimatedMinutes) min", bundle: .module)].joined(separator: " · ")
    }

    /// « 5 exercices, environ 55 minutes ».
    static func editorSummarySpoken(exerciseCount: Int, estimatedMinutes: Int) -> String {
        [exercises(exerciseCount), approximateMinutes(estimatedMinutes)].joined(separator: ", ")
    }

    /// « 4 routines · 3 séances par semaine » : le résumé d'un programme.
    static func programSummary(routineCount: Int, sessionsPerWeek: Int) -> String {
        [routines(routineCount), String(localized: "\(sessions(sessionsPerWeek)) par semaine", bundle: .module)]
            .joined(separator: " · ")
    }

    /// « 4 routines, 3 séances par semaine ».
    static func programSummarySpoken(routineCount: Int, sessionsPerWeek: Int) -> String {
        [routines(routineCount), String(localized: "\(sessions(sessionsPerWeek)) par semaine", bundle: .module)]
            .joined(separator: ", ")
    }

    // MARK: - Exercice de routine

    /// « 3 × 8–12 · RPE 8 · repos 2 min » ; « Par série · 4–12 · … » avec une fourchette par série ; « 30–60 s » pour un
    /// exercice tenu.
    static func routineExerciseSummary(_ exercise: RoutineExercise, tracksDuration: Bool) -> String {
        let unit = tracksDuration ? " s" : ""
        let range = "\(exercise.repsMin)\u{2013}\(exercise.repsMax)\(unit)"
        let volume = exercise.setTargets == nil
            ? String(localized: "\(exercise.sets) × \(range)", bundle: .module)
            : String(localized: "Par série · \(range)", bundle: .module)
        let rpe = PulseFormat.decimal(exercise.targetRPE, maxFractionDigits: 1)
        let rest = PulseFormat.restDuration(seconds: exercise.restSeconds)
        return String(localized: "\(volume) · RPE \(rpe) · repos \(rest)", bundle: .module)
    }

    /// « 3 séries de 8 à 12 répétitions, RPE 8, repos 2 minutes » ; « par série, de 4 à 12 répétitions, … » avec une fourchette
    /// par série ; « 3 séries de 30 à 60 secondes, … » pour un exercice tenu.
    static func routineExerciseSpoken(_ exercise: RoutineExercise, tracksDuration: Bool) -> String {
        let range = spokenRange(min: exercise.repsMin, max: exercise.repsMax, tracksDuration: tracksDuration)
        let volume = exercise.setTargets == nil
            ? String(localized: "\(sets(exercise.sets)) de \(range)", bundle: .module)
            : String(localized: "par série, de \(range)", bundle: .module)
        let rpe = String(localized: "RPE \(PulseFormat.decimal(exercise.targetRPE, maxFractionDigits: 1))", bundle: .module)
        let rest = String(localized: "repos \(PulseSpoken.duration(seconds: exercise.restSeconds))", bundle: .module)
        return [volume, rpe, rest].joined(separator: ", ")
    }

    /// L'en-tête d'un exercice replié : « Développé couché, 3 séries de 8 à 12 répétitions, RPE 8, repos 2 minutes », suivi de
    /// « à corriger » quand ses réglages ont une erreur.
    /// `supersetLabel` : « A2 » quand l'exercice est dans un super set, dit « super set A2 ».
    static func routineExerciseLabel(name: String, exercise: RoutineExercise, tracksDuration: Bool, hasIssue: Bool,
                                     supersetLabel: String? = nil) -> String {
        var label = String(localized: "\(name), \(routineExerciseSpoken(exercise, tracksDuration: tracksDuration))", bundle: .module)
        if let supersetLabel { label = String(localized: "\(label), super set \(supersetLabel)", bundle: .module) }
        return hasIssue ? String(localized: "\(label), à corriger", bundle: .module) : label
    }

    /// « 8 à 12 répétitions », « 8 répétitions » quand le minimum égale le maximum ; en secondes pour un exercice tenu.
    static func spokenRange(min: Int, max: Int, tracksDuration: Bool) -> String {
        let unit = tracksDuration ? secondsUnit(max) : repetitionsUnit(max)
        return min == max
            ? String(localized: "\(max) \(unit)", bundle: .module)
            : String(localized: "\(min) à \(max) \(unit)", bundle: .module)
    }

    /// Le nom du pas à pas d'une borne : « Répétitions minimum », « Durée maximale, série 2 ». `setNumber` vaut `nil` quand la
    /// fourchette est commune à toutes les séries.
    static func rangeStepperLabel(isMaximum: Bool, tracksDuration: Bool, setNumber: Int?) -> String {
        let base: String
        switch (tracksDuration, isMaximum) {
        case (false, false): base = String(localized: "Répétitions minimum", bundle: .module)
        case (false, true): base = String(localized: "Répétitions maximum", bundle: .module)
        case (true, false): base = String(localized: "Durée minimale", bundle: .module)
        case (true, true): base = String(localized: "Durée maximale", bundle: .module)
        }
        guard let setNumber else { return base }
        return String(localized: "\(base), série \(setNumber)", bundle: .module)
    }

    /// La valeur d'une borne : « 8 répétitions », « 45 secondes ».
    static func rangeStepperValue(_ value: Int, tracksDuration: Bool) -> String {
        tracksDuration ? PulseSpoken.duration(seconds: value) : PulseSpoken.repetitions(value)
    }

    // MARK: - Correction d'une séance

    /// Ce que mesure un champ de la correction.
    enum CorrectionField {
        case weight
        case reps
        case duration
    }

    /// « Charge de la série 2, en kilos », « Répétitions de la série 2 », « Durée de la série 2, en secondes ».
    static func correctionFieldLabel(_ field: CorrectionField, setNumber: Int) -> String {
        switch field {
        case .weight: String(localized: "Charge de la série \(setNumber), en kilos", bundle: .module)
        case .reps: String(localized: "Répétitions de la série \(setNumber)", bundle: .module)
        case .duration: String(localized: "Durée de la série \(setNumber), en secondes", bundle: .module)
        }
    }

    /// « Mon programme, 4 routines, 3 séances par semaine » : une ligne de liste dont le détail est dit en mots.
    static func rowSpoken(title: String, detail: String) -> String {
        String(localized: "\(title), \(detail)", bundle: .module)
    }

    /// « Squat, Squat, barre » : une alternative d'exercice, sans « · ».
    static func alternativeSpoken(name: String, pattern: String, equipment: String) -> String {
        String(localized: "\(name), \(pattern), \(equipment.lowercased())", bundle: .module)
    }

    // MARK: - Interne

    private static func repetitionsUnit(_ count: Int) -> String {
        count <= 1 ? String(localized: "répétition", bundle: .module) : String(localized: "répétitions", bundle: .module)
    }

    private static func secondsUnit(_ count: Int) -> String {
        count <= 1 ? String(localized: "seconde", bundle: .module) : String(localized: "secondes", bundle: .module)
    }

    /// Le type puis l'objectif d'une course ; le type est omis quand le jour porte déjà son nom, et « Course » tient lieu de
    /// résumé quand il ne reste rien.
    private static func runParts(_ day: RoutineDay, goal: String?) -> [String] {
        let fallback = String(localized: "Course", bundle: .module)
        let type = day.runType?.localizedName ?? fallback
        let parts = (type == day.name ? [] : [type]) + [goal].compactMap { $0 }
        return parts.isEmpty ? [fallback] : parts
    }

    /// « lundi, jeudi » ; « hors semaine type » pour une routine qu'aucun jour ne planifie.
    private static func days(of routine: RoutineSummary) -> String {
        guard !routine.weekdays.isEmpty else { return String(localized: "hors semaine type", bundle: .module) }
        return routine.weekdays.map(\.trainName).joined(separator: ", ")
    }
}
