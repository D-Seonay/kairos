import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

/// Ce que VoiceOver dit de l'onglet Séance, et les pluriels affichés : des fonctions pures.
@Suite struct TrainTextTests {
    private let bench = ExerciseReference.content(id: "bench-press-barbell")

    private func set(_ weight: Double?, reps: Int? = nil, seconds: Int? = nil) -> WorkoutSet {
        WorkoutSet(order: 0, exercise: bench, exerciseName: "Exercice", setType: .working, actualWeightKg: weight, actualReps: reps,
                   durationSeconds: seconds)
    }

    // MARK: Pluriels

    @Test func countsUseTheSingularUpToOne() {
        #expect(TrainText.exercises(1) == "1 exercice" && TrainText.exercises(5) == "5 exercices")
        #expect(TrainText.sets(1) == "1 série" && TrainText.sets(12) == "12 séries")
        #expect(TrainText.sessions(1) == "1 séance" && TrainText.sessions(42) == "42 séances")
        #expect(TrainText.routines(1) == "1 routine" && TrainText.routines(4) == "4 routines")
        #expect(TrainText.records(1) == "1 record" && TrainText.records(2) == "2 records")
        #expect(TrainText.repetitions(1) == "1 répétition" && TrainText.repetitions(8) == "8 répétitions")
    }

    @Test func importTitleAndResultAgreeWithTheCount() {
        #expect(TrainText.importTitle(sessions: 1) == "Importer 1 séance")
        #expect(TrainText.importTitle(sessions: 42) == "Importer 42 séances")
        #expect(TrainText.importedSessions(1) == "1 séance importée")
        #expect(TrainText.importedSessions(42) == "42 séances importées")
    }

    @Test func kilometresAndTonnageAreSaidInFull() {
        #expect(TrainText.kilometres(1) == "1 kilomètre" && TrainText.kilometres(1.5) == "1,5 kilomètre")
        #expect(TrainText.kilometres(10) == "10 kilomètres")
        let tonnage = TrainText.tonnage(12_450.4)
        #expect(tonnage.hasSuffix(" kilos") && tonnage.filter(\.isNumber) == "12450")
    }

    // MARK: Séries dites en mots

    @Test func aSetIsSaidWithItsLoadAndValue() {
        #expect(TrainText.spokenSet(of: set(70, reps: 5), loadKind: .external) == "70 kilos, 5 répétitions")
        #expect(TrainText.spokenSet(of: set(72.5, reps: 1), loadKind: .external) == "72,5 kilos, 1 répétition")
        #expect(TrainText.spokenSet(of: set(15, reps: 8), loadKind: .assisted) == "assistance de 15 kilos, 8 répétitions")
        #expect(TrainText.spokenSet(of: set(10, reps: 8), loadKind: .bodyweight) == "lest de 10 kilos, 8 répétitions")
        #expect(TrainText.spokenSet(of: set(nil, reps: 8), loadKind: .bodyweight) == "8 répétitions")
        #expect(TrainText.spokenSet(of: set(nil, seconds: 45), loadKind: .external) == "45 secondes")
        #expect(TrainText.spokenSet(of: set(nil, seconds: 90), loadKind: .external) == "1 minute 30")
        #expect(TrainText.spokenSet(of: set(nil), loadKind: .external) == "non renseignée")
    }

    @Test func setsOfTheSameLoadAreCounted() {
        let sets = [set(70, reps: 5), set(70, reps: 5)]
        #expect(TrainText.spokenSets(sets, loadKind: .external) == "70 kilos, 2 séries de 5 répétitions")
        #expect(TrainText.spokenSets([set(70, reps: 5)], loadKind: .external) == "70 kilos, 5 répétitions")
    }

    @Test func loadChangesAreSeparatedByPuis() {
        let sets = [set(60, reps: 8), set(70, reps: 5), set(70, reps: 5), set(70, reps: 4)]
        #expect(TrainText.spokenSets(sets, loadKind: .external)
            == "60 kilos, 8 répétitions, puis 70 kilos, 2 séries de 5 répétitions puis 4 répétitions")
    }

    @Test func assistedHeldAndUnloadedGroupsAreSpokenToo() {
        #expect(TrainText.spokenSets([set(25, reps: 8), set(15, reps: 6)], loadKind: .assisted)
            == "assistance de 25 kilos, 8 répétitions, puis assistance de 15 kilos, 6 répétitions")
        #expect(TrainText.spokenSets([set(nil, seconds: 45), set(nil, seconds: 45)], loadKind: .external)
            == "2 séries de 45 secondes")
        #expect(TrainText.spokenSets([], loadKind: .external) == "non renseignée")
    }

    @Test func theBestSetIsSaidByItsLoadKind() {
        let date = Date(timeIntervalSince1970: 0)
        #expect(TrainText.spokenBestSet(BestSet(weightKg: 72.5, reps: 5, date: date)) == "72,5 kilos, 5 répétitions")
        #expect(TrainText.spokenBestSet(BestSet(weightKg: 15, reps: 8, date: date, isAssisted: true))
            == "assistance de 15 kilos, 8 répétitions")
        #expect(TrainText.spokenBestSet(BestSet(weightKg: 10, reps: 8, date: date, isBodyweight: true))
            == "lest de 10 kilos, 8 répétitions")
        #expect(TrainText.spokenBestSet(BestSet(weightKg: 0, reps: 12, date: date)) == "12 répétitions")
        #expect(BestSet(weightKg: 0, reps: 1, date: date).text == "1 répétition")
    }

    @Test func aSessionSetCarriesItsTypeRPEAndRecord() {
        var line = SessionSetLine(id: UUID(), text: "40 × 10", spokenText: "40 kilos, 10 répétitions", type: .warmup, rpe: nil,
                                  isRecord: false)
        #expect(TrainText.sessionSetSpoken(line) == "40 kilos, 10 répétitions, échauffement")
        line = SessionSetLine(id: UUID(), text: "82,5 × 4", spokenText: "82,5 kilos, 4 répétitions", type: .working, rpe: 9.5,
                              isRecord: true)
        #expect(TrainText.sessionSetSpoken(line) == "82,5 kilos, 4 répétitions, RPE 9,5, record")
    }

    @Test func anExerciseHistoryLineIsReadInOneBreath() {
        let line = ExerciseHistoryLine(id: UUID(), date: Date(timeIntervalSince1970: 0), setsText: "70 × 5 · 5",
                                       spokenSetsText: "70 kilos, 2 séries de 5 répétitions", maxRPE: 8, tonnageKg: 700,
                                       hasRecord: true)
        #expect(TrainText.spokenHistoryLine(line, dateText: "26 octobre")
            == "26 octobre, 70 kilos, 2 séries de 5 répétitions, RPE 8, 700 kilos au total, record")
        let plain = ExerciseHistoryLine(id: UUID(), date: Date(timeIntervalSince1970: 0), setsText: "8", maxRPE: nil, tonnageKg: 0,
                                        hasRecord: false)
        #expect(TrainText.spokenHistoryLine(plain, dateText: "2 novembre") == "2 novembre, 8, 0 kilo au total")
    }

    @Test func indicatorsJoinTheirPartsAndSkipAMissingDetail() {
        #expect(TrainText.indicatorSpoken(title: "Meilleure série", value: "70 kilos, 5 répétitions", detail: "26 octobre")
            == "Meilleure série, 70 kilos, 5 répétitions, 26 octobre")
        #expect(TrainText.indicatorSpoken(title: "Meilleure série", value: "aucune série", detail: nil)
            == "Meilleure série, aucune série")
    }

    // MARK: Historique

    @Test func aHistoryRowIsSaidInWords() {
        let line = HistoryLine(id: UUID(), title: "Push", date: Date(timeIntervalSince1970: 0), durationMinutes: 65, workingSets: 12,
                               tonnageKg: 4_250, recordCount: 2, isImported: true, isAbandoned: true)
        let spoken = TrainText.historyRowSpoken(line, spokenDate: "lundi 27 octobre")
        #expect(spoken.hasPrefix("Push, importée de Hevy, abandonnée, lundi 27 octobre, 1 heure 5 minutes, 12 séries, "))
        #expect(spoken.hasSuffix(" kilos, 2 records") && !spoken.contains("kg") && !spoken.contains("·"))
        let single = HistoryLine(id: UUID(), title: "Pull", date: Date(timeIntervalSince1970: 0), durationMinutes: nil,
                                 workingSets: 1, tonnageKg: 80, recordCount: 1, isImported: false, isAbandoned: false)
        #expect(TrainText.historyRowSpoken(single, spokenDate: "mardi 28 octobre")
            == "Pull, mardi 28 octobre, 1 série, 80 kilos, 1 record")
        #expect(TrainText.historyVolume(single) == "1 série · 80 kg")
    }

    // MARK: Routines

    private func routine(_ day: RoutineDay, count: Int = 5, minutes: Int = 55,
                         weekdays: [Weekday] = [.monday, .thursday]) -> RoutineSummary {
        RoutineSummary(day: day, exerciseCount: count, estimatedMinutes: minutes, weekdays: weekdays)
    }

    @Test func aStrengthRoutineSaysApproximatelyInsteadOfATilde() {
        let push = routine(RoutineDay(order: 0, name: "Push", kind: .strength))
        #expect(TrainText.routineSubtitle(push) == "5 exercices · ~ 55 min · lundi, jeudi")
        #expect(TrainText.routineSubtitleSpoken(push) == "5 exercices, environ 55 minutes, lundi, jeudi")
        let single = routine(RoutineDay(order: 0, name: "Push", kind: .strength), count: 1, minutes: 65, weekdays: [])
        #expect(TrainText.routineSubtitle(single) == "1 exercice · ~ 65 min · hors semaine type")
        #expect(TrainText.routineSubtitleSpoken(single) == "1 exercice, environ 1 heure 5 minutes, hors semaine type")
    }

    @Test func aRunRoutineSaysItsTargetInWords() {
        let easy = routine(RoutineDay(order: 0, name: "Footing", kind: .run, runType: .easy, runTargetMinutes: 45), weekdays: [.sunday])
        #expect(TrainText.routineSubtitle(easy).hasSuffix(" · 45 min · dimanche"))
        #expect(TrainText.routineSubtitleSpoken(easy).hasSuffix(", 45 minutes, dimanche"))
        let long = routine(RoutineDay(order: 0, name: "Sortie", kind: .run, runType: .long, runTargetKm: 1), weekdays: [.sunday])
        #expect(TrainText.routineSubtitleSpoken(long).hasSuffix(", 1 kilomètre, dimanche"))
    }

    @Test func theEditorAndProgramSummariesHaveASpokenVariant() {
        #expect(TrainText.editorSummary(exerciseCount: 1, estimatedMinutes: 55) == "1 exercice · ~ 55 min")
        #expect(TrainText.editorSummarySpoken(exerciseCount: 5, estimatedMinutes: 55) == "5 exercices, environ 55 minutes")
        #expect(TrainText.programSummary(routineCount: 1, sessionsPerWeek: 1) == "1 routine · 1 séance par semaine")
        #expect(TrainText.programSummarySpoken(routineCount: 4, sessionsPerWeek: 3) == "4 routines, 3 séances par semaine")
    }

    // MARK: Exercice de routine

    private func exercise(sets: Int = 3, min: Int = 8, max: Int = 12, rpe: Double = 8, rest: Int = 120,
                          perSet: [SetTarget]? = nil) -> RoutineExercise {
        RoutineExercise(order: 0, exercise: bench, sets: sets, repsMin: min, repsMax: max, targetRPE: rpe, restSeconds: rest,
                        setTargets: perSet)
    }

    @Test func aRoutineExerciseSummaryKeepsItsSigns() {
        #expect(TrainText.routineExerciseSummary(exercise(), tracksDuration: false) == "3 × 8–12 · RPE 8 · repos 2 min")
        #expect(TrainText.routineExerciseSummary(exercise(min: 30, max: 60, rest: 90), tracksDuration: true)
            == "3 × 30–60 s · RPE 8 · repos 1 min 30")
        #expect(TrainText.routineExerciseSummary(exercise(min: 4, max: 12, perSet: [SetTarget(repsMin: 4, repsMax: 6)]),
                                                 tracksDuration: false) == "Par série · 4–12 · RPE 8 · repos 2 min")
    }

    @Test func aRoutineExerciseIsSaidInWords() {
        #expect(TrainText.routineExerciseSpoken(exercise(), tracksDuration: false)
            == "3 séries de 8 à 12 répétitions, RPE 8, repos 2 minutes")
        #expect(TrainText.routineExerciseSpoken(exercise(sets: 1, min: 5, max: 5, rpe: 8.5, rest: 90), tracksDuration: false)
            == "1 série de 5 répétitions, RPE 8,5, repos 1 minute 30")
        #expect(TrainText.routineExerciseSpoken(exercise(min: 30, max: 60, rest: 45), tracksDuration: true)
            == "3 séries de 30 à 60 secondes, RPE 8, repos 45 secondes")
        #expect(TrainText.routineExerciseSpoken(exercise(min: 4, max: 12, perSet: [SetTarget(repsMin: 4, repsMax: 6)]),
                                                tracksDuration: false)
            == "par série, de 4 à 12 répétitions, RPE 8, repos 2 minutes")
    }

    @Test func aRoutineExerciseWithAnIssueIsFlaggedInItsLabel() {
        #expect(TrainText.routineExerciseLabel(name: "Développé couché", exercise: exercise(), tracksDuration: false, hasIssue: false)
            == "Développé couché, 3 séries de 8 à 12 répétitions, RPE 8, repos 2 minutes")
        #expect(TrainText.routineExerciseLabel(name: "Développé couché", exercise: exercise(), tracksDuration: false, hasIssue: true)
            == "Développé couché, 3 séries de 8 à 12 répétitions, RPE 8, repos 2 minutes, à corriger")
    }

    @Test func rangeSteppersNameTheirBoundAndSeries() {
        #expect(TrainText.rangeStepperLabel(isMaximum: false, tracksDuration: false, setNumber: nil) == "Répétitions minimum")
        #expect(TrainText.rangeStepperLabel(isMaximum: true, tracksDuration: false, setNumber: 2) == "Répétitions maximum, série 2")
        #expect(TrainText.rangeStepperLabel(isMaximum: false, tracksDuration: true, setNumber: nil) == "Durée minimale")
        #expect(TrainText.rangeStepperLabel(isMaximum: true, tracksDuration: true, setNumber: 1) == "Durée maximale, série 1")
        #expect(TrainText.rangeStepperValue(8, tracksDuration: false) == "8 répétitions")
        #expect(TrainText.rangeStepperValue(90, tracksDuration: true) == "1 minute 30")
    }

    // MARK: Correction, bibliothèque, import

    @Test func correctionFieldsNameTheirSet() {
        #expect(TrainText.correctionFieldLabel(.weight, setNumber: 2) == "Charge de la série 2, en kilos")
        #expect(TrainText.correctionFieldLabel(.reps, setNumber: 2) == "Répétitions de la série 2")
        #expect(TrainText.correctionFieldLabel(.duration, setNumber: 3) == "Durée de la série 3, en secondes")
    }

    @Test func libraryRowsSaySeparatorsAndOneRepMaxInWords() {
        #expect(TrainText.exerciseRowSubtitle(group: "Pectoraux", equipment: "Barre", oneRepMax: 65) == "Pectoraux · barre · 1RM 65 kg")
        #expect(TrainText.exerciseRowSubtitleSpoken(group: "Pectoraux", equipment: "Barre", oneRepMax: 65)
            == "Pectoraux, barre, maximum estimé 65 kilos")
        #expect(TrainText.exerciseRowSubtitleSpoken(group: "Dos", equipment: "Poulie", oneRepMax: nil) == "Dos, poulie")
        #expect(TrainText.addSelectionTitle(count: 0) == "Ajouter" && TrainText.addSelectionTitle(count: 3) == "Ajouter (3)")
        #expect(TrainText.addSelectionSpoken(count: 0) == "Ajouter")
        #expect(TrainText.addSelectionSpoken(count: 1) == "Ajouter 1 exercice")
        #expect(TrainText.addSelectionSpoken(count: 3) == "Ajouter 3 exercices")
    }

    @Test func importRowsCountWithPluralsAndSpeakWithoutDots() {
        #expect(TrainText.mappingCounts(sessions: 1, sets: 1) == "1 séance · 1 série")
        #expect(TrainText.mappingCounts(sessions: 12, sets: 80) == "12 séances · 80 séries")
        #expect(TrainText.mappingRowSpoken(name: "Bench Press", sessions: 12, sets: 80, choice: "Développé couché", needsReview: true)
            == "Bench Press, 12 séances, 80 séries. Choix : Développé couché, à vérifier")
        #expect(TrainText.mappingRowSpoken(name: "Squat", sessions: 1, sets: 3, choice: "Ignoré", needsReview: false)
            == "Squat, 1 séance, 3 séries. Choix : Ignoré")
        #expect(TrainText.spokenPeriod(from: "3 septembre 2026", to: "26 octobre 2026") == "du 3 septembre 2026 au 26 octobre 2026")
        #expect(TrainText.spokenPeriod(from: "3 septembre 2026", to: "3 septembre 2026") == "3 septembre 2026")
    }
}
