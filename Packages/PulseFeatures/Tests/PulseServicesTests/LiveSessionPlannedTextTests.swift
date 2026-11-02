import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

/// La phrase des valeurs prévues, partagée par la notification de fin de repos et le bandeau de repos de l'écran.
struct LiveSessionPlannedTextTests {
    private func exercise(_ loadKind: LoadKind, tracksDuration: Bool = false) -> LiveExercise {
        LiveExercise(exercise: .content(id: "bench-press-barbell"), name: "Test", loadKind: loadKind, tracksDuration: tracksDuration,
                     isBarbell: false, incrementKg: 2.5, restSeconds: 60, sets: [])
    }

    private func set(weight: Double? = nil, reps: Int? = nil, seconds: Int? = nil) -> LiveSet {
        LiveSet(proposed: ProposedSet(weightKg: weight, reps: reps, durationSeconds: seconds), previous: nil)
    }

    @Test func externalLoadHasKilosAndReps() {
        #expect(exercise(.external).plannedText(for: set(weight: 72.5, reps: 5)) == "72,5 kg × 5")
    }

    @Test func bodyweightAndAssistedLoadsAreSigned() {
        #expect(exercise(.bodyweight).plannedText(for: set(weight: 10, reps: 8)) == "+10 kg × 8")
        #expect(exercise(.assisted).plannedText(for: set(weight: 20, reps: 6)) == "\u{2212}20 kg × 6")
    }

    @Test func withoutLoadOnlyTheValueRemains() {
        #expect(exercise(.bodyweight).plannedText(for: set(reps: 12)) == "12 rép.")
        #expect(exercise(.bodyweight, tracksDuration: true).plannedText(for: set(seconds: 45)) == "45 s")
        #expect(exercise(.external).plannedText(for: set()) == nil)
    }
}
