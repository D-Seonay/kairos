import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct HevySessionBuilderTests {
    private let directory = ExerciseDirectory(library: .bundled, userExercises: [ExerciseDirectoryTests.shrug])
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let pecDeck = ExerciseReference.content(id: "pec-deck-machine")

    private func workouts(_ text: String) throws -> [HevyWorkout] {
        HevyWorkouts.group(try HevyCSV.rows(from: Data(text.utf8), calendar: TestClock.calendar))
    }

    private func build(_ text: String, references: [String: ExerciseReference]) throws -> WorkoutSession? {
        let workout = try #require(workouts(text).first)
        return HevySessionBuilder.session(from: workout, references: references, directory: directory, now: .t0)
    }

    @Test func builderConvertsTypesSupersetsNotesAndTonnage() throws {
        let workout = try #require(workouts(HevyFixtures.csv).first)
        let session = try #require(HevySessionBuilder.session(from: workout, references: [
            "Développé Couché (Barre)": .content(id: "bench-press-barbell"), "Écarté (Machine)": .content(id: "pec-deck-machine")
        ], directory: directory, now: .t0))
        #expect(session.source == .hevy && session.status == .completed && session.durationMinutes == 66)
        #expect(session.kind == .strength && session.title == "Push 🫷🫸")
        #expect(session.startedAt == TestClock.date("2026-10-26T07:00") && session.endedAt == TestClock.date("2026-10-26T08:06"))
        #expect(session.note == "Note, avec \"guillemets\"\net retour")
        #expect(session.sets.map(\.setType) == [.warmup, .working, .drop])
        #expect(session.sets.map(\.order) == [0, 1, 2])
        #expect(session.exerciseNotes == [ExerciseNote(exercise: .content(id: "pec-deck-machine"), text: "Siège cran 4 — l’épaule ok")])
        #expect(session.tonnageKg == 60 * 12 + 72.5 * 5)
        #expect(session.sets[0].exerciseName == "Développé couché à la barre")
        #expect(session.createdAt == .t0 && session.updatedAt == .t0)
    }

    @Test func setsCarryTheMeasuredValuesAndNoCompletionDate() throws {
        let session = try #require(try build(HevyFixtures.csv, references: ["Développé Couché (Barre)": bench]))
        #expect(session.sets.count == 2)
        #expect(session.sets[0].actualWeightKg == nil && session.sets[0].actualReps == 20 && session.sets[0].rpe == 6)
        #expect(session.sets[1].actualWeightKg == 60 && session.sets[1].actualReps == 12 && session.sets[1].rpe == 7.5)
        #expect(session.sets.allSatisfy { $0.completedAt == nil && $0.exercise == bench && $0.supersetGroup == nil })
        #expect(session.exerciseNotes.isEmpty)
    }

    @Test(arguments: [("normal", SetType.working), ("warmup", .warmup), ("dropset", .drop), ("failure", .failure), ("autre", .working)])
    func setTypesConvert(hevyType: String, expected: SetType) throws {
        let text = HevyFixtures.csv(HevyFixtures.row("Bench", type: hevyType, weight: "50", reps: "5"))
        #expect(try build(text, references: ["Bench": bench])?.sets.map(\.setType) == [expected])
    }

    @Test func supersetIDsBecomeGroupsAndOnlyIgnoredExercisesYieldNoSession() throws {
        let text = HevyFixtures.csv(
            HevyFixtures.row("Bench", superset: "0", weight: "50", reps: "5"),
            HevyFixtures.row("Pec", superset: "0", weight: "30", reps: "10"),
            HevyFixtures.row("Pec", superset: "0", weight: "30", reps: "9"),
            HevyFixtures.row("Solo", weight: "20", reps: "8"),
            HevyFixtures.row("Tapis", distance: "1.4", seconds: "600"))
        let references: [String: ExerciseReference] = ["Bench": bench, "Pec": pecDeck, "Solo": .user(id: ExerciseDirectoryTests.shrug.id)]
        let session = try #require(try build(text, references: references))
        #expect(session.sets.map(\.supersetGroup) == [1, 1, 1, nil])
        #expect(session.sets.map(\.exerciseName) == ["Développé couché à la barre", "Écarté à la machine", "Écarté à la machine",
                                                    "Shrug (Haltère)"])
        #expect(try build(text, references: [:]) == nil)
        #expect(try build(text, references: ["Tapis": bench])?.sets.isEmpty == false)
        #expect(try build(text, references: ["Inconnu": bench]) == nil)
    }

    @Test func rowsWithoutLoadRepsOrDurationAreSkipped() throws {
        let text = HevyFixtures.csv(
            HevyFixtures.row("Bench", weight: "50", reps: "5"),
            HevyFixtures.row("Bench"),
            HevyFixtures.row("Bench", distance: "2"),
            HevyFixtures.row("Bench", seconds: "30"))
        let session = try #require(try build(text, references: ["Bench": bench]))
        #expect(session.sets.map(\.order) == [0, 1])
        #expect(session.sets.map(\.durationSeconds) == [nil, 30])
        let onlyEmpty = HevyFixtures.csv(HevyFixtures.row("Bench"), HevyFixtures.row("Bench", distance: "2"))
        #expect(try build(onlyEmpty, references: ["Bench": bench]) == nil)
    }

    @Test func notesOfIgnoredExercisesAreDropped() throws {
        let text = HevyFixtures.csv(
            HevyFixtures.row("Bench", notes: "Prise large", weight: "50", reps: "5"),
            HevyFixtures.row("Pec", notes: "Cran 4", weight: "30", reps: "10"))
        let session = try #require(try build(text, references: ["Bench": bench]))
        #expect(session.exerciseNotes == [ExerciseNote(exercise: bench, text: "Prise large")])
    }

    @Test func durationNeverGoesNegativeAcrossTheAutumnDSTChange() throws {
        let text = HevyFixtures.csv(HevyFixtures.row("Bench", start: "25 oct. 2026, 02:30", end: "25 oct. 2026, 02:10",
                                                     weight: "50", reps: "5"))
        let session = try #require(try build(text, references: ["Bench": bench]))
        #expect(session.durationMinutes == 0)
    }

    @Test func endNeverPrecedesStartAcrossTheAutumnDSTChange() throws {
        let text = HevyFixtures.csv(HevyFixtures.row("Bench", start: "25 oct. 2026, 02:30", end: "25 oct. 2026, 02:10",
                                                     weight: "50", reps: "5"))
        let session = try #require(try build(text, references: ["Bench": bench]))
        #expect(session.endedAt == session.startedAt)
    }

    @Test func assistedExercisesDoNotAddTonnage() throws {
        let text = HevyFixtures.csv(HevyFixtures.row("Dips", weight: "30", reps: "10"))
        let session = try #require(try build(text, references: ["Dips": .content(id: "assisted-dips-machine")]))
        #expect(session.tonnageKg == 0 && session.sets[0].actualWeightKg == 30)
    }
}
