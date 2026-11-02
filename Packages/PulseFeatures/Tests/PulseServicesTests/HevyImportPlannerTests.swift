import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct HevyImportPlannerTests {
    private func rows(_ text: String = HevyFixtures.csv) throws -> [HevyRow] {
        try HevyCSV.rows(from: Data(text.utf8), calendar: TestClock.calendar)
    }

    private func plan(
        _ text: String = HevyFixtures.csv, existing: [WorkoutSession] = [], userExercises: [UserExercise] = [],
        remembered: [String: HevyMappingChoice] = [:], library: ContentLibrary = .bundled
    ) throws -> HevyImportPreview {
        try HevyImportPlanner.preview(rows: rows(text), existing: existing, library: library, userExercises: userExercises,
                                      remembered: remembered)
    }

    private func hevySession(_ start: String, title: String, source: SessionSource = .hevy) -> WorkoutSession {
        WorkoutSession(startedAt: TestClock.date(start), kind: .strength, source: source, status: .completed, title: title,
                       createdAt: .t0, updatedAt: .t0)
    }

    private func choice(_ name: String, in preview: HevyImportPreview) -> HevyMappingChoice? {
        preview.names.first { $0.name == name }?.choice
    }

    @Test func previewSkipsDuplicatesAndFlagsCardio() throws {
        let existing = [hevySession("2026-10-27T07:17", title: "Pull")]
        let preview = try plan(existing: existing)
        #expect(preview.newWorkouts.map(\.title) == ["Push 🫷🫸"])
        #expect(preview.duplicateCount == 1)
        #expect(preview.cardioSetCount == 1)
        #expect(preview.names.first { $0.name == "Tapis de Course" }?.choice == .ignore)
        #expect(preview.names.first { $0.name == "Tapis de Course" }?.isCardio == true)
        #expect(preview.names.first { $0.name == "Écarté (Machine)" }?.choice == .content(id: "pec-deck-machine"))
        #expect(preview.names.first { $0.name == "Écarté (Machine)" }?.isSure == true)
        #expect(preview.period == TestClock.date("2026-10-26T07:00")...TestClock.date("2026-10-26T07:00"))
    }

    @Test func duplicatesNeedTheHevySourceTheSameMinuteAndTheSameTitle() throws {
        let existing = [
            hevySession("2026-10-27T07:17", title: "Pull", source: .pulse),
            hevySession("2026-10-27T07:18", title: "Pull"),
            hevySession("2026-10-27T07:17", title: "Pull ")
        ]
        let preview = try plan(existing: existing)
        #expect(preview.duplicateCount == 0 && preview.newWorkouts.count == 2)
        var shifted = hevySession("2026-10-27T07:17", title: "Pull")
        shifted.startedAt.addTimeInterval(42)
        #expect(try plan(existing: [shifted]).duplicateCount == 1)
    }

    @Test func namesAreCountedAndSortedBySessionsThenName() throws {
        let text = HevyFixtures.csv(
            HevyFixtures.row("Zèbre", weight: "10", reps: "5"),
            HevyFixtures.row("Zèbre", weight: "10", reps: "5"),
            HevyFixtures.row("Abeille", weight: "10", reps: "5"),
            HevyFixtures.row("Zèbre", title: "Autre", start: "4 nov. 2026, 10:00", end: "4 nov. 2026, 11:00", weight: "10", reps: "5"),
            HevyFixtures.row("Ânon", title: "Autre", start: "4 nov. 2026, 10:00", end: "4 nov. 2026, 11:00", weight: "10", reps: "5"))
        let names = try plan(text).names
        #expect(names.map(\.name) == ["Zèbre", "Abeille", "Ânon"])
        #expect(names.map(\.sessionCount) == [2, 1, 1])
        #expect(names.map(\.setCount) == [3, 1, 1])
        #expect(names.map(\.id) == ["Zèbre", "Abeille", "Ânon"])
    }

    @Test func namesOfDuplicateWorkoutsAreLeftOut() throws {
        let preview = try plan(existing: [hevySession("2026-10-27T07:17", title: "Pull")])
        #expect(!preview.names.contains { $0.name == "Extension Triceps Poulie Haute" })
    }

    @Test func unknownNamesGetADraftAndKeepTheirSureFlagOff() throws {
        let text = HevyFixtures.csv(HevyFixtures.row("Shrug (Haltère)", weight: "20", reps: "10"))
        let preview = try plan(text)
        let summary = try #require(preview.names.first)
        #expect(summary.isSure == false && summary.isCardio == false)
        #expect(summary.choice == .create(HevyNameGuesser.draft(for: "Shrug (Haltère)")))
    }

    @Test func aNameIsCardioOnlyWhenEveryLineLacksLoadAndReps() throws {
        let text = HevyFixtures.csv(
            HevyFixtures.row("Vélo", distance: "3", seconds: "600"),
            HevyFixtures.row("Vélo", weight: "10", reps: "5"),
            HevyFixtures.row("Rameur", seconds: "300"),
            HevyFixtures.row("Rameur", distance: "1.2"),
            HevyFixtures.row("Série vide"))
        let preview = try plan(text)
        #expect(preview.names.first { $0.name == "Vélo" }?.isCardio == false)
        #expect(preview.names.first { $0.name == "Rameur" }?.isCardio == true)
        #expect(preview.names.first { $0.name == "Série vide" }?.isCardio == false)
        #expect(preview.cardioSetCount == 2)
    }

    /// Une séance sans aucune ligne chargée ni répétée, mais avec du cardio, n'est pas importée : elle est comptée à part.
    @Test func cardioOnlyWorkoutsAreCountedApart() throws {
        let text = HevyFixtures.csv(
            HevyFixtures.row("Course", title: "Cardio", start: "4 nov. 2026, 10:00", end: "4 nov. 2026, 11:00", distance: "5",
                             seconds: "1800"),
            HevyFixtures.row("Rameur", title: "Cardio", start: "4 nov. 2026, 10:00", end: "4 nov. 2026, 11:00", seconds: "300"),
            HevyFixtures.row("Développé Couché (Barre)", weight: "60", reps: "8"),
            HevyFixtures.row("Rameur", seconds: "600"))
        let preview = try plan(text)
        #expect(preview.newWorkouts.map(\.title) == ["Test"])
        #expect(preview.cardioOnlyWorkoutCount == 1)
        #expect(preview.cardioSetCount == 1)
        #expect(preview.names.map(\.name).sorted() == ["Développé Couché (Barre)", "Rameur"])
        #expect(preview.period == TestClock.date("2026-11-03T10:00")...TestClock.date("2026-11-03T10:00"))
    }

    /// Une séance aux lignes toutes vides n'est pas du cardio : elle reste à importer, et l'import dira qu'elle n'a rien donné.
    @Test func aWorkoutOfEmptyLinesIsNotCardioOnly() throws {
        let preview = try plan(HevyFixtures.csv(HevyFixtures.row("Série vide")))
        #expect(preview.cardioOnlyWorkoutCount == 0)
        #expect(preview.newWorkouts.count == 1)
    }

    @Test func rememberedAndUserExerciseChoicesWin() throws {
        let shrug = ExerciseDirectoryTests.shrug
        let text = HevyFixtures.csv(
            HevyFixtures.row("Écarté (Machine)", weight: "10", reps: "5"),
            HevyFixtures.row("Shrug (Haltère)", weight: "10", reps: "5"),
            HevyFixtures.row("Curl Marteau", weight: "10", reps: "5"))
        let remembered: [String: HevyMappingChoice] = ["Écarté (Machine)": .content(id: "dumbbell-curl")]
        let preview = try plan(text, userExercises: [shrug], remembered: remembered)
        #expect(choice("Écarté (Machine)", in: preview) == .content(id: "dumbbell-curl"))
        #expect(preview.names.first { $0.name == "Écarté (Machine)" }?.isSure == true)
        #expect(choice("Shrug (Haltère)", in: preview) == .user(id: shrug.id))
        #expect(preview.names.first { $0.name == "Shrug (Haltère)" }?.isSure == false)
        if case .create = choice("Curl Marteau", in: preview) {} else { Issue.record("Curl Marteau doit proposer une création") }
    }

    @Test func userExerciseMatchesTheFoldedNameAndSkipsArchivedOnes() throws {
        var shrug = ExerciseDirectoryTests.shrug
        shrug.name = "SHRUG  (haltere)"
        let text = HevyFixtures.csv(HevyFixtures.row("Shrug (Haltère)", weight: "10", reps: "5"))
        #expect(try choice("Shrug (Haltère)", in: plan(text, userExercises: [shrug])) == .user(id: shrug.id))
        shrug.isArchived = true
        if case .create = try choice("Shrug (Haltère)", in: plan(text, userExercises: [shrug])) {} else {
            Issue.record("un exercice archivé ne doit pas être proposé")
        }
    }

    @Test func rememberedChoiceIsDroppedWhenItNoLongerDesignatesAnExercise() throws {
        let archived: UserExercise = {
            var exercise = ExerciseDirectoryTests.shrug
            exercise.isArchived = true
            return exercise
        }()
        var retired = try #require(ContentLibrary.bundled.exercise(id: "pec-deck-machine"))
        retired.retired = true
        let catalog = ExerciseCatalog(schemaVersion: 1, contentVersion: "test", exercises: [retired])
        let library = ContentLibrary(catalog: catalog, templates: [], hevyNames: ["Écarté (Machine)": "pec-deck-machine"])
        let draft = HevyNameGuesser.draft(for: "Machine X")
        let text = HevyFixtures.csv(
            HevyFixtures.row("Écarté (Machine)", weight: "10", reps: "5"), HevyFixtures.row("A", weight: "10", reps: "5"),
            HevyFixtures.row("B", weight: "10", reps: "5"), HevyFixtures.row("C", weight: "10", reps: "5"),
            HevyFixtures.row("D", weight: "10", reps: "5"), HevyFixtures.row("E", weight: "10", reps: "5"))
        let remembered: [String: HevyMappingChoice] = [
            "Écarté (Machine)": .content(id: "pec-deck-machine"), "A": .content(id: "inconnu"), "B": .user(id: UUID()),
            "C": .user(id: archived.id), "D": .create(draft), "E": .ignore
        ]
        let preview = try plan(text, userExercises: [archived], remembered: remembered, library: library)
        // Retiré : la mémoire est écartée, et la table ne désigne plus un exercice proposé.
        if case .create = choice("Écarté (Machine)", in: preview) {} else { Issue.record("exercice retiré") }
        #expect(preview.names.first { $0.name == "Écarté (Machine)" }?.isSure == false)
        if case .create = choice("A", in: preview) {} else { Issue.record("identifiant inconnu") }
        if case .create = choice("B", in: preview) {} else { Issue.record("exercice perso inconnu") }
        #expect(choice("C", in: preview) == .user(id: archived.id))
        #expect(choice("D", in: preview) == .create(draft))
        #expect(choice("E", in: preview) == .ignore)
    }

    @Test func emptyRowsAreRejected() {
        #expect(throws: HevyImportError.empty) {
            try HevyImportPlanner.preview(rows: [], existing: [], library: .bundled, userExercises: [], remembered: [:])
        }
    }

    @Test func everythingAlreadyImportedLeavesNoPeriod() throws {
        let existing = [hevySession("2026-10-26T07:00", title: "Push 🫷🫸"), hevySession("2026-10-27T07:17", title: "Pull")]
        let preview = try plan(existing: existing)
        #expect(preview.newWorkouts.isEmpty && preview.duplicateCount == 2 && preview.names.isEmpty)
        #expect(preview.period == nil && preview.cardioSetCount == 0)
    }

    @Test func periodSpansTheFirstAndLastNewWorkout() throws {
        let preview = try plan()
        #expect(preview.period == TestClock.date("2026-10-26T07:00")...TestClock.date("2026-10-27T07:17"))
    }
}
