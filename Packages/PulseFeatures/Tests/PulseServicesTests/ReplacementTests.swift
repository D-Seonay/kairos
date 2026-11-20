import Foundation
import PulseDomain
import PulseRecoveryEngine
@testable import PulseServices
import Testing

/// Remplacer un exercice en séance (spec M4 §8.3, §19.3).
struct ReplacementTests {
    private typealias Fix = LiveFixtures
    private let dumbbellBench = ExerciseReference.content(id: "bench-press-dumbbell")
    private let chestPress = ExerciseReference.content(id: "chest-press-machine")
    private let inclineDumbbell = ExerciseReference.content(id: "incline-bench-press-dumbbell")
    private let flatBench = [Fix.done(Fix.bench, 60, 10), Fix.done(Fix.bench, 60, 9), Fix.done(Fix.bench, 60, 8)]

    private func profile(_ access: EquipmentAccess) -> UserProfile {
        var profile = Fix.profile()
        profile.equipmentAccess = access
        return profile
    }

    /// Le développé couché : 60 kg × 11, 10, 9, la première série validée.
    private func benchSession() -> LiveSession {
        var session = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench, rpe: 7.5, rest: 150)]), nil),
                                  history: [Fix.bench: flatBench])
        let bench = session.exercises[0]
        session.applyStructure(.validate(exercise: bench.id, set: bench.sets[0].id), now: .t0)
        return session
    }

    @Test func theContentAlternativesComeFirst() {
        let picked = ReplacementPlanner.alternatives(for: Fix.bench, directory: Fix.directory, profile: profile(.fullGym),
                                                     excluding: [])
        #expect(picked.map(\.reference) == [chestPress, dumbbellBench, .content(id: "incline-chest-press-machine")])
    }

    @Test func alternativesFollowTheEquipmentAndSkipWhatIsInTheSession() {
        let home = ReplacementPlanner.alternatives(for: Fix.bench, directory: Fix.directory, profile: profile(.homeGym),
                                                   excluding: [inclineDumbbell])
        #expect(home.first?.reference == dumbbellBench)
        #expect(home.allSatisfy { EquipmentAccess.homeGym.allowedEquipment.contains($0.equipment) })
        #expect(!home.contains { $0.reference == inclineDumbbell || $0.reference == Fix.bench })
        #expect(home.count <= ReplacementPlanner.alternativeCount)
    }

    @Test func withoutHistoryTheReplacementTakesTheEquivalentLoad() throws {
        let session = benchSession()
        let replacement = try #require(ReplacementPlanner.replacement(
            of: session.exercises[0], with: dumbbellBench, reason: .machineBusy, directory: Fix.directory, history: [],
            settings: nil, profile: Fix.profile(), policy: session.policy))
        // Deux séries restaient, de 10 et 9 répétitions : même nombre, même repos, même plafond de RPE.
        let working = replacement.sets.filter { $0.setType == .working }
        #expect(working.count == 2)
        let load = try #require(working.first?.proposed.weightKg)
        #expect(load > 0 && load < 60)
        #expect(working.allSatisfy { $0.proposed.weightKg == load && $0.weightKg == load && !$0.isEdited })
        #expect(replacement.restSeconds == session.exercises[0].restSeconds)
        #expect(replacement.rpeCap == session.exercises[0].rpeCap)
        #expect(replacement.replacedExercise == Fix.bench && replacement.replacementReason == .machineBusy)
        #expect(replacement.dayNote == "Remplace Développé couché à la barre · charge estimée, à ajuster")
    }

    @Test func withHistoryTheReplacementUsesItsOwnValues() throws {
        let session = benchSession()
        let history = [Fix.done(chestPress, 50, 9), Fix.done(chestPress, 50, 9)]
        let replacement = try #require(ReplacementPlanner.replacement(
            of: session.exercises[0], with: chestPress, reason: .pain, directory: Fix.directory, history: history,
            settings: nil, profile: Fix.profile(), policy: session.policy))
        #expect(replacement.sets.first?.proposed.weightKg == 50)
        #expect(replacement.dayNote == "Remplace Développé couché à la barre")
        #expect(replacement.lastTimeText != nil)
    }

    @Test func nothingLeftToReplaceGivesNoReplacement() {
        var session = benchSession()
        let bench = session.exercises[0]
        for set in bench.sets.dropFirst() {
            session.applyStructure(.validate(exercise: bench.id, set: set.id), now: .t0)
        }
        #expect(ReplacementPlanner.replacement(of: session.exercises[0], with: dumbbellBench, reason: .other,
                                               directory: Fix.directory, history: [], settings: nil, profile: Fix.profile(),
                                               policy: session.policy) == nil)
    }

    @Test func validatedSetsStayAndTheReplacementFollows() throws {
        var session = benchSession()
        let replacement = try #require(ReplacementPlanner.replacement(
            of: session.exercises[0], with: dumbbellBench, reason: .machineBusy, directory: Fix.directory, history: [],
            settings: nil, profile: Fix.profile(), policy: session.policy))
        session.applyStructure(.replaceExercise(session.exercises[0].id, with: replacement), now: .t0)
        #expect(session.exercises.map(\.exercise) == [Fix.bench, dumbbellBench])
        #expect(session.exercises[0].sets.count == 1 && session.exercises[0].sets[0].completedAt != nil)
    }

    @Test func anUntouchedExerciseIsReplacedInPlace() throws {
        let session0 = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench, order: 0), Fix.exercise(Fix.pecDeck, order: 1)]),
                                              nil), history: [Fix.bench: flatBench])
        var session = session0
        let replacement = try #require(ReplacementPlanner.replacement(
            of: session.exercises[0], with: chestPress, reason: .pain, directory: Fix.directory, history: [],
            settings: nil, profile: Fix.profile(), policy: session.policy))
        session.applyStructure(.replaceExercise(session.exercises[0].id, with: replacement), now: .t0)
        #expect(session.exercises.map(\.exercise) == [chestPress, Fix.pecDeck])
    }

    @Test func savedSetsRememberWhatTheyReplaced() throws {
        var session = benchSession()
        let replacement = try #require(ReplacementPlanner.replacement(
            of: session.exercises[0], with: dumbbellBench, reason: .machineBusy, directory: Fix.directory, history: [],
            settings: nil, profile: Fix.profile(), policy: session.policy))
        session.applyStructure(.replaceExercise(session.exercises[0].id, with: replacement), now: .t0)
        let added = session.exercises[1]
        session.applyStructure(.validate(exercise: added.id, set: added.sets[0].id), now: .t1)
        let saved = session.workoutSession(status: .completed, endedAt: .t1, overallRPE: nil, note: nil, savedAt: .t1)
        #expect(saved.sets.map(\.exercise) == [Fix.bench, dumbbellBench])
        #expect(saved.sets[0].replacedExercise == nil)
        #expect(saved.sets[1].replacedExercise == Fix.bench && saved.sets[1].replacementReason == .machineBusy)
    }
}
