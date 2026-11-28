import Foundation
import PulseDomain
import PulseRecoveryEngine
@testable import PulseServices
import Testing

/// La baisse des charges après une pause ou deux séances sous la fourchette (`LoadDropRule`), « Remettre », et la note de la
/// dernière fois reprise sur la carte.
struct LiveSessionLoadDropTests {
    private typealias Fix = LiveFixtures
    private let flat = [Fix.done(Fix.bench, 100, 10), Fix.done(Fix.bench, 100, 10), Fix.done(Fix.bench, 100, 10)]

    /// Trois séries de bench à 100 kg, `reps` faites sur `planned` proposées.
    private func bench(_ reps: [Int], planned: Int = 8, weightKg: Double = 100) -> [WorkoutSet] {
        reps.map { Fix.done(Fix.bench, weightKg, $0, planned: planned) }
    }

    private func recent(_ daysAgo: Int, sets: [WorkoutSet]? = nil, note: String? = nil,
                        deloaded: Bool = false) -> RecentExerciseSession {
        RecentExerciseSession(startedAt: Date.t0.addingTimeInterval(-Double(daysAgo) * 86_400), isDeloaded: deloaded,
                              sets: sets ?? flat, note: note)
    }

    private func benchSession(history: [WorkoutSet]? = nil, recent: [RecentExerciseSession], warmups: Bool = false,
                              deload: DeloadStatus = .none) -> LiveSession {
        let launch = SessionLaunch.routine(Fix.day([Fix.exercise(Fix.bench)]), programID: nil, recovery: nil, originalChosen: false,
                                           profile: Fix.profile(), deload: deload)
        return Fix.session(launch, history: [Fix.bench: history ?? flat], warmups: warmups, recent: [Fix.bench: recent])
    }

    @Test func aLayoffLowersTheLoadsToTheBottomOfTheRangeAndSaysWhy() throws {
        let bench = benchSession(recent: [recent(36)]).exercises[0]
        #expect(bench.sets.map(\.proposed.weightKg) == [85, 85, 85])
        #expect(bench.sets.map(\.proposed.reps) == [8, 8, 8])
        #expect(bench.sets.map(\.weightKg) == [85, 85, 85])
        let drop = try #require(bench.loadDrop)
        #expect(drop.text == "Reprise après 5 semaines : −15 %")
        #expect(drop.originalWeightKg == 100 && drop.originalSets.map(\.reps) == [11, 11, 11])
        #expect(bench.dayNote == nil)
    }

    @Test func aLayoffReplacesTheIncrease() {
        let topped = [Fix.done(Fix.bench, 100, 12), Fix.done(Fix.bench, 100, 12), Fix.done(Fix.bench, 100, 12)]
        let session = benchSession(history: topped, recent: [recent(50, sets: topped)])
        let bench = session.exercises[0]
        #expect(bench.sets.map(\.proposed.weightKg) == [80, 80, 80])
        #expect(bench.sets.allSatisfy { !$0.proposed.isIncrease })
        #expect(bench.loadDrop?.originalSets.map(\.weightKg) == [102.5, 102.5, 102.5])
        #expect(!session.appliedAdjustments.contains { $0.kind == .load })
        #expect(bench.dayNote == nil)
    }

    @Test func twoMissedSessionsLowerOnlyThatExercise() throws {
        let missed = bench([7, 8, 8])
        let pecSets = [Fix.done(Fix.pecDeck, 50, 10), Fix.done(Fix.pecDeck, 50, 10)]
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0), Fix.exercise(Fix.pecDeck, order: 1)])
        let session = Fix.session(Fix.launch(day, nil), history: [Fix.bench: missed, Fix.pecDeck: pecSets],
                                  recent: [Fix.bench: [recent(3, sets: missed), recent(6, sets: missed)],
                                           Fix.pecDeck: [recent(3, sets: pecSets), recent(6, sets: pecSets)]])
        let bench = session.exercises[0]
        #expect(bench.sets.map(\.proposed.weightKg) == [95, 95, 95])
        #expect(try #require(bench.loadDrop).text == "Deux séances sous la fourchette : −5 %")
        #expect(session.exercises[1].loadDrop == nil)
        #expect(session.exercises[1].sets.map(\.proposed.weightKg) == [50, 50, 50])
    }

    @Test func anExerciseAddedWithTheDefaultRangeIsJudgedOnItsOwnPastTargets() {
        // Un bench fait en 5 × 5, ajouté en séance : la fourchette par défaut (8–12) ne transforme pas 5 sur 5 en échecs.
        let fives = bench([5, 5, 5], planned: 5)
        let added = LiveSessionPlanner.exercise(Fix.bench, directory: Fix.directory, history: fives, settings: nil,
                                                profile: Fix.profile(), policy: ProgressionPolicy(allowsIncrease: true),
                                                recent: [recent(3, sets: fives), recent(6, sets: fives)], now: .t0)
        #expect(added.loadDrop == nil)
    }

    @Test func aDeloadedSessionBetweenTwoMissesIsSkippedButStillEndsTheLayoff() {
        let missed = bench([6, 6, 6])
        let bench = benchSession(history: missed, recent: [recent(2, deloaded: true), recent(20, sets: missed),
                                                           recent(23, sets: missed)]).exercises[0]
        #expect(bench.loadDrop?.text == "Deux séances sous la fourchette : −10 %")
    }

    @Test func aDeloadWeekThatAlreadyLowersMoreKeepsTheDeloadOnly() {
        let missed = bench([7, 8, 8])
        let bench = benchSession(history: missed, recent: [recent(3, sets: missed), recent(6, sets: missed)],
                                 deload: .active(since: .distantPast, until: .distantFuture)).exercises[0]
        #expect(bench.loadDrop == nil)
        #expect(bench.sets.first?.proposed.weightKg == 90)
    }

    @Test func restoringPutsTheOldLoadsBackOnTheSetsStillToDo() throws {
        var session = benchSession(recent: [recent(36)])
        let bench = session.exercises[0]
        session.applyStructure(.validate(exercise: bench.id, set: bench.sets[0].id), now: .t0)
        session.applyStructure(.edit(exercise: bench.id, set: bench.sets[2].id, weightKg: 90), now: .t0)
        session.applyStructure(.restoreLoads(exercise: bench.id), now: .t0)
        let restored = session.exercises[0]
        #expect(restored.sets.map(\.weightKg) == [85, 100, 90])
        #expect(restored.sets.map(\.reps) == [8, 11, 8])
        #expect(restored.sets[1].proposed == ProposedSet(weightKg: 100, reps: 11) && !restored.sets[1].isEdited)
        #expect(restored.loadDrop == nil)
        let again = session
        session.applyStructure(.restoreLoads(exercise: bench.id), now: .t0)
        #expect(session == again)
    }

    @Test func restoringRecomputesTheWarmups() throws {
        var session = benchSession(recent: [recent(36)], warmups: true)
        let bench = session.exercises[0]
        let lowWarmups = bench.sets.filter { $0.setType == .warmup }.map(\.weightKg)
        #expect(!lowWarmups.isEmpty)
        session.applyStructure(.restoreLoads(exercise: bench.id), now: .t0)
        let plain = Fix.session(Fix.launch(Fix.day([Fix.exercise(Fix.bench)]), nil), history: [Fix.bench: flat], warmups: true)
        let expected = plain.exercises[0].sets.filter { $0.setType == .warmup }.map(\.weightKg)
        #expect(session.exercises[0].sets.filter { $0.setType == .warmup }.map(\.weightKg) == expected)
        #expect(expected != lowWarmups)
    }

    @Test func theNoteOfLastTimeIsPinnedToTheCard() {
        #expect(benchSession(recent: [recent(3, note: "Banc cran 3"), recent(6, note: "Ancienne")]).exercises[0].note
                == "Banc cran 3")
        #expect(benchSession(recent: [recent(3), recent(6, note: "Ancienne")]).exercises[0].note == nil)
        #expect(benchSession(recent: []).exercises[0].note == nil)
    }

    @Test func anAddedExerciseGetsTheDropAndTheNoteToo() {
        let added = LiveSessionPlanner.exercise(Fix.bench, directory: Fix.directory, history: flat, settings: nil,
                                                profile: Fix.profile(), policy: ProgressionPolicy(allowsIncrease: true),
                                                recent: [recent(36, note: "Prise serrée")], now: .t0)
        #expect(added.loadDrop?.text == "Reprise après 5 semaines : −15 %")
        #expect(added.note == "Prise serrée")
    }
}
