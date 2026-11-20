@testable import LiveSessionFeature
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct ReplaceExerciseSheetTests {
    private func exercise(weight: Double?, reps: Int?, sets: Int, lastTime: String?) -> LiveExercise {
        let proposed = ProposedSet(weightKg: weight, reps: reps)
        let warmup = LiveSet(setType: .warmup, proposed: ProposedSet(weightKg: 10, reps: 5))
        return LiveExercise(exercise: .content(id: "bench-press-dumbbell"), name: "Développé couché aux haltères",
                            loadKind: .external, tracksDuration: false, isBarbell: false, incrementKg: 2, restSeconds: 120,
                            lastTimeText: lastTime,
                            sets: [warmup] + Array(repeating: LiveSet(proposed: proposed, previous: nil), count: sets))
    }

    @Test func proposalTextSaysTheSetsTheLoadAndWhetherItIsEstimated() {
        #expect(ReplaceExerciseSheet.proposalText(exercise(weight: 24, reps: 10, sets: 2, lastTime: nil))
                == "2 séries · 24 kg × 10 · charge estimée")
        #expect(ReplaceExerciseSheet.proposalText(exercise(weight: 22.5, reps: 8, sets: 1, lastTime: "Dernière fois 22,5 × 8"))
                == "1 série · 22,5 kg × 8")
        #expect(ReplaceExerciseSheet.proposalText(exercise(weight: nil, reps: 12, sets: 3, lastTime: nil))
                == "3 séries · 12 répétitions")
    }

    @Test func everyReasonHasALabel() {
        #expect(ReplacementReason.allCases.map(ReplaceExerciseSheet.label(for:)) == ["Machine occupée", "Douleur", "Autre"])
    }
}
