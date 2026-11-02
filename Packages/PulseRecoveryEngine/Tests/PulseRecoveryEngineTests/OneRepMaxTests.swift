import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

struct OneRepMaxTests {
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let dips = ExerciseReference.content(id: "dips-assisted")
    private let extensionRef = ExerciseReference.content(id: "back-extension")

    private func set(_ exercise: ExerciseReference, _ type: SetType, _ weight: Double?, _ reps: Int?, order: Int) -> WorkoutSet {
        WorkoutSet(order: order, exercise: exercise, exerciseName: "Exercice", setType: type, actualWeightKg: weight, actualReps: reps)
    }

    private func kind(of exercise: ExerciseReference) -> LoadKind {
        switch exercise {
        case dips: .assisted
        case extensionRef: .bodyweight
        default: .external
        }
    }

    @Test func brzyckiMatchesTheFormulaAndStopsAt12Reps() {
        #expect(OneRepMax.brzycki(weightKg: 70, reps: 5).map { ($0 * 100).rounded() / 100 } == 78.75)
        #expect(OneRepMax.brzycki(weightKg: 60, reps: 12) == Double(60) * 36 / 25)
        #expect(OneRepMax.brzycki(weightKg: 60, reps: 13) == nil)
        #expect(OneRepMax.brzycki(weightKg: 0, reps: 5) == nil)
        #expect(OneRepMax.brzycki(weightKg: 60, reps: 0) == nil)
    }

    @Test func tonnageSkipsWarmupsAndCountsOnlyAddedWeight() {
        let sets = [
            set(bench, .warmup, 20, 10, order: 0),
            set(bench, .working, 60, 12, order: 1),
            set(bench, .working, 70, 5, order: 2),
            set(dips, .working, 12.5, 12, order: 3),
            set(extensionRef, .working, 10, 12, order: 4)
        ]
        #expect(SessionTonnage.kilograms(of: sets, loadKind: kind(of:)) == 60 * 12 + 70 * 5 + 10 * 12)
    }

    @Test func tonnageIgnoresSetsWithoutRepsAndCountsBodyweightWithoutBallast() {
        let sets = [
            set(bench, .working, 60, nil, order: 0),
            set(bench, .working, nil, 8, order: 1),
            set(extensionRef, .working, nil, 15, order: 2)
        ]
        #expect(SessionTonnage.kilograms(of: sets, loadKind: kind(of:)) == 0)
    }
}
