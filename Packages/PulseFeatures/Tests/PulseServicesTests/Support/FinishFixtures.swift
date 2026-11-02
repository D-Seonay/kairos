import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// Des séances en cours écrites à la main pour le récap, l'enregistrement et l'abandon : elles commencent à 8 h, l'heure
/// de départ de l'horloge d'`ActiveSessionFixture`.
enum FinishFixtures {
    static let start = TestClock.date("2026-11-02T08:00")

    /// Une série aux valeurs données, validée à `time` si elle est donnée ; sa proposition vaut ses valeurs sauf `proposed`.
    static func set(_ weightKg: Double?, _ reps: Int?, type: SetType = .working, at time: String? = nil, rpe: Double? = nil,
                    proposed: ProposedSet? = nil) -> LiveSet {
        LiveSet(setType: type, proposed: proposed ?? ProposedSet(weightKg: weightKg, reps: reps), weightKg: weightKg, reps: reps,
                rpe: rpe, isEdited: proposed != nil, completedAt: time.map(TestClock.date))
    }

    /// Échauffement 20 × 10 (8:10), 60 × 12 (8:20) et 72,5 × 5 (8:40, proposé 70 × 5) validés, puis 72,5 × 5 non validée.
    static func benchSets(rpes: (Double?, Double?) = (nil, nil)) -> [LiveSet] {
        [set(20, 10, type: .warmup, at: "2026-11-02T08:10"),
         set(60, 12, at: "2026-11-02T08:20", rpe: rpes.0),
         set(72.5, 5, at: "2026-11-02T08:40", rpe: rpes.1, proposed: ProposedSet(weightKg: 70, reps: 5)),
         set(72.5, 5)]
    }

    static func bench(_ sets: [LiveSet], note: String? = nil) -> LiveExercise {
        LiveExercise(exercise: LiveFixtures.bench, name: "Développé couché à la barre", loadKind: .external, tracksDuration: false,
                     isBarbell: true, incrementKg: 2.5, restSeconds: 90, note: note, sets: sets)
    }

    static func pecDeck(_ sets: [LiveSet], note: String? = nil) -> LiveExercise {
        LiveExercise(exercise: LiveFixtures.pecDeck, name: "Écarté à la machine", loadKind: .external, tracksDuration: false,
                     isBarbell: false, incrementKg: 2.5, restSeconds: 60, note: note, sets: sets)
    }

    static func pullUp(_ sets: [LiveSet]) -> LiveExercise {
        LiveExercise(exercise: LiveFixtures.pullUp, name: "Tractions", loadKind: .bodyweight, tracksDuration: false,
                     isBarbell: false, incrementKg: 2.5, restSeconds: 120, sets: sets)
    }

    static func session(_ exercises: [LiveExercise], lastActionAt: String = "2026-11-02T08:40",
                        applied: [SessionAdjustment] = [], refused: [SessionAdjustment] = []) -> LiveSession {
        LiveSession(title: "Push", startedAt: start, lastActionAt: TestClock.date(lastActionAt), appliedAdjustments: applied,
                    refusedAdjustments: refused, exercises: exercises)
    }
}

extension ActiveSessionFixture {
    /// Enregistre la séance dans le snapshot, comme après une relance, et rend un service neuf.
    func resume(_ session: LiveSession) async throws -> ActiveSessionService {
        try await store.save(ActiveSessionSnapshot(id: session.id, startedAt: session.startedAt, updatedAt: session.lastActionAt,
                                                   payload: try session.encoded()))
        return makeService()
    }

    /// Le profil d'un onboarding terminé le 1er septembre : le ratio aigu / chronique a assez d'historique.
    func completeOnboarding() async throws {
        try await profiles.save(UserProfile(onboardingCompletedAt: TestClock.date("2026-09-01T08:00"), createdAt: .t0,
                                            updatedAt: .t0))
    }
}
