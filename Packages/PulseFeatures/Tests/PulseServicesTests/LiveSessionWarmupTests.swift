import Foundation
import PulseDomain
import PulseRecoveryEngine
@testable import PulseServices
import Testing

/// L'échauffement automatique en séance (spec M4 §8.3, §19.1).
struct LiveSessionWarmupTests {
    private typealias Fix = LiveFixtures
    private let squat = ExerciseReference.content(id: "back-squat-barbell")
    private let incline = ExerciseReference.content(id: "incline-bench-press-dumbbell")
    private let flatBench = [Fix.done(Fix.bench, 60, 10), Fix.done(Fix.bench, 60, 9), Fix.done(Fix.bench, 60, 8)]

    private func benchSession(settings: [ExerciseReference: ExerciseSettings] = [:], warmups: Bool = true) -> LiveSession {
        Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench)]), nil), history: [Fix.bench: flatBench], warmups: warmups,
                    settings: settings)
    }

    @Test func aBarbellCompoundStartsWithTheBarThenSixtyAndEightyPercent() {
        let bench = benchSession().exercises[0]
        // 60 kg de travail : barre, 60 % = 36 → 35, 80 % = 48 → 47,5 (paires de 1,25 kg).
        #expect(bench.sets.map(\.setType) == [.warmup, .warmup, .warmup, .working, .working, .working])
        #expect(bench.sets.prefix(3).map(\.proposed.weightKg) == [20, 35, 47.5])
        #expect(bench.sets.prefix(3).map(\.proposed.reps) == [10, 5, 3])
        #expect(bench.sets.prefix(3).allSatisfy { $0.weightKg == $0.proposed.weightKg && !$0.isEdited && $0.previous == nil })
        #expect(bench.warmupPlan != nil)
    }

    @Test func warmUpsStayOutOfTheWorkingSetCount() {
        let session = benchSession()
        #expect(session.plannedWorkingSets == 3)
    }

    @Test func noWarmUpWhenTheProfileTurnsItOff() {
        let bench = benchSession(warmups: false).exercises[0]
        #expect(bench.sets.allSatisfy { $0.setType == .working } && bench.warmupPlan == nil)
    }

    @Test func theExerciseSettingLimitsOrDisablesTheWarmUp() {
        let one = [Fix.bench: ExerciseSettings(exercise: Fix.bench, warmupSetCount: 1, createdAt: .t0, updatedAt: .t0)]
        #expect(benchSession(settings: one).exercises[0].sets.filter { $0.setType == .warmup }.map(\.proposed.weightKg) == [47.5])
        let off = [Fix.bench: ExerciseSettings(exercise: Fix.bench, warmupSetCount: 0, createdAt: .t0, updatedAt: .t0)]
        #expect(!benchSession(settings: off).exercises[0].sets.contains { $0.setType == .warmup })
    }

    @Test func anIsolationExerciseOrAFirstTimeLiftGetsNone() {
        let day = Fix.day([Fix.exercise(Fix.pecDeck, order: 0), Fix.exercise(squat, order: 1)])
        let session = Fix.session(Fix.launch(day, nil), history: [Fix.pecDeck: [Fix.done(Fix.pecDeck, 40, 12)]], warmups: true)
        // Le pec deck est un isolé ; le squat n'a pas d'historique, donc pas de charge de travail à préparer.
        #expect(!session.exercises[0].sets.contains { $0.setType == .warmup })
        #expect(!session.exercises[1].sets.contains { $0.setType == .warmup })
    }

    @Test func aMuscleAlreadyWorkedIsNotWarmedUpTwice() {
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0), Fix.exercise(incline, order: 1), Fix.exercise(squat, order: 2)])
        let history = [Fix.bench: flatBench, incline: [Fix.done(incline, 24, 10)], squat: [Fix.done(squat, 100, 5)]]
        let session = Fix.session(Fix.launch(day, nil), history: history, warmups: true)
        #expect(session.exercises[0].sets.contains { $0.setType == .warmup })
        // Les pectoraux sont déjà chauds après le développé couché ; les cuisses ne le sont pas.
        #expect(!session.exercises[1].sets.contains { $0.setType == .warmup })
        #expect(session.exercises[2].sets.contains { $0.setType == .warmup })
    }

    @Test func changingTheFirstWorkingLoadRecomputesTheWarmUp() throws {
        var session = benchSession()
        let bench = session.exercises[0]
        let ids = bench.sets.prefix(3).map(\.id)
        session.applyStructure(.edit(exercise: bench.id, set: bench.sets[3].id, weightKg: 100), now: .t0)
        let warmups = session.exercises[0].sets.prefix(3)
        #expect(warmups.map(\.weightKg) == [20, 60, 80])
        #expect(warmups.map(\.id) == ids)
    }

    @Test func aTouchedWarmUpOrAValidatedWorkingSetFreezesTheWarmUp() {
        var touched = benchSession()
        let bench = touched.exercises[0]
        touched.applyStructure(.edit(exercise: bench.id, set: bench.sets[1].id, weightKg: 40), now: .t0)
        touched.applyStructure(.edit(exercise: bench.id, set: bench.sets[3].id, weightKg: 100), now: .t0)
        #expect(touched.exercises[0].sets.prefix(3).map(\.weightKg) == [20, 40, 47.5])

        var validated = benchSession()
        validated.applyStructure(.validate(exercise: bench.id, set: bench.sets[3].id), now: .t0)
        validated.applyStructure(.edit(exercise: bench.id, set: bench.sets[3].id, weightKg: 100), now: .t0)
        #expect(validated.exercises[0].sets.prefix(3).map(\.weightKg) == [20, 35, 47.5])
    }

    @Test func aDeletedWarmUpDoesNotComeBack() {
        var session = benchSession()
        let bench = session.exercises[0]
        session.applyStructure(.deleteSet(exercise: bench.id, set: bench.sets[0].id), now: .t0)
        session.applyStructure(.edit(exercise: bench.id, set: bench.sets[3].id, weightKg: 100), now: .t0)
        #expect(session.exercises[0].sets.filter { $0.setType == .warmup }.map(\.weightKg) == [60, 80])
    }

    @Test func aSessionSavedBeforeWarmUpPlansStillDecodes() throws {
        let session = benchSession()
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        var exercises = try #require(json["exercises"] as? [[String: Any]])
        exercises[0].removeValue(forKey: "warmupPlan")
        json["exercises"] = exercises
        let decoded = try JSONDecoder().decode(LiveSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.exercises[0].warmupPlan == nil)
        #expect(decoded.exercises[0].sets.count == 6)
    }

    @Test func theCountChosenInSessionRebuildsTheWarmUp() {
        var session = benchSession()
        let bench = session.exercises[0]
        session.applyStructure(.setWarmupCount(exercise: bench.id, 1), now: .t0)
        #expect(session.exercises[0].sets.filter { $0.setType == .warmup }.map(\.weightKg) == [47.5])
        #expect(session.exercises[0].warmupPlan?.maxCount == 1)
        session.applyStructure(.setWarmupCount(exercise: bench.id, nil), now: .t0)
        #expect(session.exercises[0].sets.filter { $0.setType == .warmup }.map(\.weightKg) == [20, 35, 47.5])
        session.applyStructure(.setWarmupCount(exercise: bench.id, 0), now: .t0)
        #expect(!session.exercises[0].sets.contains { $0.setType == .warmup })
        #expect(session.exercises[0].sets.count == 3)
    }

    @Test func theCountIsSavedInTheExerciseSettings() async throws {
        let fixture = ActiveSessionFixture()
        let service = fixture.makeService()
        try await fixture.settings.save(ExerciseSettings(exercise: Fix.bench, incrementKg: 1.25, createdAt: .t0, updatedAt: .t0))
        try await service.saveWarmupCount(2, for: Fix.bench)
        let saved = try #require(try await fixture.settings.settings(for: Fix.bench))
        #expect(saved.warmupSetCount == 2 && saved.incrementKg == 1.25)
        try await service.saveWarmupCount(1, for: Fix.pecDeck)
        #expect(try await fixture.settings.settings(for: Fix.pecDeck)?.warmupSetCount == 1)
    }
}
