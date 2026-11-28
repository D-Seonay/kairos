import Foundation
import PulseDomain
import Testing

/// Une séance passée vue depuis un exercice : ses séries hors échauffement et sa note, reprise par la séance suivante.
struct RecentExerciseSessionTests {
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let row = ExerciseReference.content(id: "row")

    private func session(notes: [ExerciseNote]) -> WorkoutSession {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let set = WorkoutSet(order: 0, exercise: bench, exerciseName: "Bench", setType: .working, actualWeightKg: 60,
                             actualReps: 8)
        return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed, title: "Push",
                              exerciseNotes: notes, sets: [set], createdAt: start, updatedAt: start)
    }

    @Test func theSameExerciseTwiceKeepsBothNotes() {
        // Le bench deux fois dans la routine : la note modifiée sur la seconde carte n'est pas perdue.
        let notes = [ExerciseNote(exercise: bench, text: "Banc cran 3"), ExerciseNote(exercise: row, text: "Sangles"),
                     ExerciseNote(exercise: bench, text: "Prise serrée")]
        #expect(RecentExerciseSession(session(notes: notes), exercise: bench)?.note == "Banc cran 3\nPrise serrée")
    }

    @Test func identicalOrEmptyNotesAreNotRepeated() {
        let notes = [ExerciseNote(exercise: bench, text: "Banc cran 3"), ExerciseNote(exercise: bench, text: " "),
                     ExerciseNote(exercise: bench, text: "Banc cran 3")]
        #expect(RecentExerciseSession(session(notes: notes), exercise: bench)?.note == "Banc cran 3")
        #expect(RecentExerciseSession(session(notes: [ExerciseNote(exercise: bench, text: "")]), exercise: bench)?.note == nil)
    }
}
