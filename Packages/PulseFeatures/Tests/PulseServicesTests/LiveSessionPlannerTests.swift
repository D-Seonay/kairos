import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct LiveSessionPlannerTests {
    private typealias Fix = LiveFixtures
    private let profile = UserProfile(createdAt: .t0, updatedAt: .t0)

    @Test func aFatigueDayPlanKeepsLoadsAndSaysWhatChanged() {
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0, rpe: 8, rest: 120), Fix.exercise(Fix.pecDeck, order: 1, rpe: 7, rest: 60)])
        let session = Fix.session(Fix.launch(day, .moderateFatigue), history: [Fix.bench: Fix.rampingBench])
        let bench = session.exercises[0]
        #expect(bench.sets.count == 2)
        #expect(bench.sets.map(\.proposed.weightKg) == [60, 70])
        #expect(bench.dayNote == "Même charge, une série en moins, RPE 7,5 max, repos 2:45")
        #expect(bench.lastTimeText == "Dernière fois 60 × 12 · 70 × 5 · 5")
        #expect(bench.sets.map(\.previous) == ["60 × 12", "70 × 5"])
        #expect(bench.restSeconds == 165 && bench.rpeCap == 7.5)
        #expect(session.appliedAdjustments.map(\.kind) == [.volume, .rpeCap, .rest])
        // Pas d'historique ni de RPE abaissé : seul le repos a changé.
        let pecDeck = session.exercises[1]
        #expect(pecDeck.dayNote == "Repos 1:45" && pecDeck.rpeCap == nil && pecDeck.lastTimeText == nil)
        #expect(pecDeck.sets.map(\.previous) == [nil, nil, nil])
    }

    @Test func aNormalDayAddsTheLoadAdjustment() {
        let day = Fix.day([Fix.exercise(Fix.bench, rest: 90)])
        let history = [Fix.bench: [Fix.done(Fix.bench, 60, 12), Fix.done(Fix.bench, 60, 12), Fix.done(Fix.bench, 60, 10)]]
        let session = Fix.session(Fix.launch(day, .normal), history: history)
        let bench = session.exercises[0]
        #expect(bench.sets.map(\.proposed.weightKg) == [62.5, 62.5, 60])
        #expect(bench.sets.map(\.proposed.reps) == [8, 8, 11])
        #expect(bench.sets.map(\.proposed.isIncrease) == [true, true, false])
        #expect(session.appliedAdjustments.map(\.kind) == [.rest, .load])
        let reason = "Développé couché à la barre : +2,5 kg sur 2 séries, 12 répétitions atteintes la dernière fois"
        #expect(session.appliedAdjustments.last?.reason == reason)
        #expect(bench.dayNote == "\(reason), repos 1:45")
        #expect(bench.restSeconds == 105)
    }

    @Test func proposedValuesStartAsTheSetValues() {
        let day = Fix.day([Fix.exercise(Fix.bench)])
        let session = Fix.session(Fix.launch(day, .optimal), history: [Fix.bench: Fix.rampingBench])
        for set in session.exercises[0].sets {
            #expect(set.weightKg == set.proposed.weightKg && set.reps == set.proposed.reps)
            #expect(set.durationSeconds == nil && set.rpe == nil && !set.isEdited && set.completedAt == nil)
            #expect(set.setType == .working)
        }
    }

    @Test func aDayWithoutScoreOrAdaptationChangesNothing() {
        let day = Fix.day([Fix.exercise(Fix.bench)])
        let history = [Fix.bench: [Fix.done(Fix.bench, 60, 10), Fix.done(Fix.bench, 60, 9), Fix.done(Fix.bench, 60, 8)]]
        let session = Fix.session(Fix.launch(day, nil), history: history)
        #expect(session.appliedAdjustments.isEmpty && session.refusedAdjustments.isEmpty)
        #expect(session.exercises[0].sets.map(\.proposed.reps) == [11, 10, 9])
        #expect(session.exercises[0].dayNote == nil)
        #expect(session.exercises[0].restSeconds == 90)
    }

    @Test func overreachedLaunchStartsTheOriginalWithoutIncrease() {
        let day = Fix.day([Fix.exercise(Fix.bench)])
        let history = [Fix.bench: [Fix.done(Fix.bench, 60, 12), Fix.done(Fix.bench, 60, 12), Fix.done(Fix.bench, 60, 12)]]
        let session = Fix.session(Fix.launch(day, .overreached), history: history)
        #expect(session.exercises[0].sets.count == 3)
        #expect(session.exercises[0].sets.map(\.proposed.weightKg) == [60, 60, 60])
        #expect(session.exercises[0].sets.map(\.proposed.isIncrease) == [false, false, false])
        #expect(session.exercises[0].dayNote == "Même charge")
        #expect(session.appliedAdjustments.isEmpty)
        #expect(session.refusedAdjustments.map(\.kind) == [.replaceWithMobility])
    }

    @Test func barbellLoadsRoundToPlatesAndOthersByIncrement() {
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0), Fix.exercise(Fix.pecDeck, order: 1)])
        let history = [Fix.bench: [Fix.done(Fix.bench, 60, 12)], Fix.pecDeck: [Fix.done(Fix.pecDeck, 35, 12)]]
        var small = profile
        small.availablePlatesKg = [20, 5, 2]
        let session = LiveSessionPlanner.session(for: Fix.launch(day, nil), directory: Fix.directory, history: history,
                                                 settings: [:], profile: small, now: .t0)
        // Barre 20 + paires de 2 kg : 60 + 2,5 → 64 ; machine : 35 + 2,5.
        #expect(session.exercises[0].sets.first?.proposed.weightKg == 64)
        #expect(session.exercises[1].sets.first?.proposed.weightKg == 37.5)
        #expect(session.exercises[0].isBarbell && !session.exercises[1].isBarbell)
    }

    @Test func theExerciseSettingOverridesTheIncrement() {
        let day = Fix.day([Fix.exercise(Fix.pecDeck)])
        let settings = [Fix.pecDeck: ExerciseSettings(exercise: Fix.pecDeck, incrementKg: 1, createdAt: .t0, updatedAt: .t0)]
        let session = LiveSessionPlanner.session(for: Fix.launch(day, nil), directory: Fix.directory,
                                                 history: [Fix.pecDeck: [Fix.done(Fix.pecDeck, 35, 12)]], settings: settings,
                                                 profile: profile, now: .t0)
        #expect(session.exercises[0].incrementKg == 1)
        #expect(session.exercises[0].sets.first?.proposed.weightKg == 36)
    }

    @Test func aFreeSessionStartsEmpty() {
        let session = Fix.session(.free(policy: ProgressionPolicy(allowsIncrease: true)))
        #expect(session.title == "Séance libre")
        #expect(session.exercises.isEmpty && session.programID == nil && session.routineDayID == nil)
        #expect(session.startedAt == .t0 && session.lastActionAt == .t0 && session.rest == nil)
        #expect(session.formatVersion == LiveSession.currentFormat)
    }

    @Test func aRoutineSessionKeepsItsOrigin() {
        let programID = UUID()
        let day = Fix.day([Fix.exercise(Fix.bench)])
        let launch = SessionLaunch.routine(day, programID: programID, recovery: nil, originalChosen: false, profile: profile)
        let session = Fix.session(launch)
        #expect(session.title == "Push" && session.programID == programID && session.routineDayID == day.id)
    }

    @Test func addedExerciseGetsThreeSetsAndItsDefaultRest() {
        let added = LiveSessionPlanner.exercise(Fix.bench, directory: Fix.directory, history: [], settings: nil, profile: profile,
                                                policy: ProgressionPolicy(allowsIncrease: true))
        #expect(added.sets.count == 3 && added.restSeconds == 120)
        #expect(added.sets.map(\.proposed.reps) == [8, 8, 8] && added.sets.allSatisfy { $0.proposed.weightKg == nil })
        #expect(added.name == "Développé couché à la barre" && added.dayNote == nil && added.lastTimeText == nil)
        let held = LiveSessionPlanner.exercise(Fix.plank, directory: Fix.directory, history: [], settings: nil, profile: profile,
                                               policy: ProgressionPolicy(allowsIncrease: true))
        #expect(held.tracksDuration && held.restSeconds == 60)
        #expect(held.sets.map(\.proposed.durationSeconds) == [30, 30, 30] && held.sets.allSatisfy { $0.proposed.reps == nil })
    }

    @Test func addedExerciseUsesItsHistoryAndTheDaysPolicy() {
        let history = [Fix.done(Fix.pecDeck, 35, 12), Fix.done(Fix.pecDeck, 35, 12), Fix.done(Fix.pecDeck, 35, 12)]
        let open = LiveSessionPlanner.exercise(Fix.pecDeck, directory: Fix.directory, history: history, settings: nil,
                                               profile: profile, policy: ProgressionPolicy(allowsIncrease: true))
        #expect(open.sets.map(\.proposed.weightKg) == [37.5, 37.5, 37.5])
        #expect(open.dayNote?.hasPrefix("Écarté à la machine : +2,5 kg") == true)
        let closed = LiveSessionPlanner.exercise(Fix.pecDeck, directory: Fix.directory, history: history, settings: nil,
                                                 profile: profile, policy: ProgressionPolicy(allowsIncrease: false))
        #expect(closed.sets.map(\.proposed.weightKg) == [35, 35, 35] && closed.dayNote == "Même charge")
    }

    @Test func anUnknownExerciseFallsBackToProfileRestAndAGenericName() {
        let unknown = ExerciseReference.user(id: UUID())
        var custom = profile
        custom.defaultRestSeconds = 75
        let added = LiveSessionPlanner.exercise(unknown, directory: Fix.directory, history: [], settings: nil, profile: custom,
                                                policy: ProgressionPolicy(allowsIncrease: true))
        #expect(added.restSeconds == 75 && added.sets.count == 3 && added.name == "Exercice inconnu")
        #expect(added.loadKind == .external && !added.isBarbell)
    }

    @Test func previousTextsFollowTheLoadKind() {
        let history = [
            Fix.pullUp: [Fix.done(Fix.pullUp, 10, 8), Fix.done(Fix.pullUp, 10, 7), Fix.done(Fix.pullUp, nil, 6)],
            Fix.assistedPullUp: [Fix.done(Fix.assistedPullUp, 20, 8)],
            Fix.plank: [Fix.done(Fix.plank, nil, nil, seconds: 45)]
        ]
        let day = Fix.day([Fix.exercise(Fix.pullUp, order: 0), Fix.exercise(Fix.assistedPullUp, order: 1, sets: 1),
                          Fix.exercise(Fix.plank, order: 2, sets: 1, reps: 30...60)])
        let session = Fix.session(Fix.launch(day, nil), history: history)
        #expect(session.exercises[0].sets.map(\.previous) == ["+10 × 8", "+10 × 7", "6"])
        #expect(session.exercises[0].lastTimeText == "Dernière fois +10 × 8 · 7 · 0 × 6")
        #expect(session.exercises[1].sets.map(\.previous) == ["−20 × 8"])
        #expect(session.exercises[2].sets.map(\.previous) == ["45 s"])
        #expect(session.exercises[2].lastTimeText == "Dernière fois 45 s")
    }

    @Test func decimalsAreFrench() {
        let history = [Fix.pecDeck: [Fix.done(Fix.pecDeck, 37.5, 10)]]
        let session = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.pecDeck)]), nil), history: history)
        #expect(session.exercises[0].lastTimeText == "Dernière fois 37,5 × 10")
    }

    @Test func supersetMembersKeepTheirGroup() {
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0, superset: 1), Fix.exercise(Fix.pecDeck, order: 1, superset: 1)])
        let session = Fix.session(Fix.launch(day, nil))
        #expect(session.exercises.map(\.supersetGroup) == [1, 1])
    }
}
