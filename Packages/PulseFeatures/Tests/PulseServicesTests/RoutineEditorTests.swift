import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct RoutineEditorTests {
    private let directory = ExerciseDirectory(library: .bundled, userExercises: [])
    private let emptyDay = RoutineDay(order: 0, name: "Push", kind: .strength)
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let pecDeck = ExerciseReference.content(id: "pec-deck-machine")
    private let plank = ExerciseReference.content(id: "plank")

    private func day(_ references: [ExerciseReference]) -> RoutineDay {
        RoutineEditor.add(references, to: emptyDay, directory: directory)
    }

    private func names(_ day: RoutineDay) -> [String] {
        day.exercises.map { directory.name(of: $0.exercise, fallback: "?") }
    }

    @Test func addedExercisesGetTheDefaults() throws {
        let day = day([bench, plank])
        #expect(day.exercises.map(\.order) == [0, 1])
        let first = day.exercises[0]
        #expect(first.exercise == bench && first.sets == 3 && first.repsMin == 8 && first.repsMax == 12)
        #expect(first.targetRPE == 8 && first.restSeconds == 120 && first.supersetGroup == nil && first.setTargets == nil)
        let held = day.exercises[1]
        #expect(held.repsMin == 30 && held.repsMax == 60 && held.restSeconds == 60)
        #expect(Set(day.exercises.map(\.id)).count == 2)
    }

    @Test func addingAppendsAfterTheExistingExercises() {
        let day = RoutineEditor.add([pecDeck], to: day([bench]), directory: directory)
        #expect(day.exercises.map(\.exercise) == [bench, pecDeck] && day.exercises.map(\.order) == [0, 1])
    }

    @Test func anUnknownReferenceStillGetsUsableDefaults() {
        let unknown = ExerciseReference.user(id: UUID())
        let added = day([unknown]).exercises[0]
        #expect(added.exercise == unknown && added.sets == 3 && added.repsMin == 8 && added.restSeconds == 90)
    }

    @Test func movingReordersAndRenumbers() {
        let base = day([bench, pecDeck, plank])
        let moved = RoutineEditor.move(fromOffsets: IndexSet(integer: 0), toOffset: 3, in: base)
        #expect(moved.exercises.map(\.exercise) == [pecDeck, plank, bench] && moved.exercises.map(\.order) == [0, 1, 2])
        let up = RoutineEditor.move(fromOffsets: IndexSet(integer: 2), toOffset: 0, in: base)
        #expect(up.exercises.map(\.exercise) == [plank, bench, pecDeck])
        let several = RoutineEditor.move(fromOffsets: IndexSet([0, 1]), toOffset: 3, in: base)
        #expect(several.exercises.map(\.exercise) == [plank, bench, pecDeck])
        #expect(RoutineEditor.move(fromOffsets: IndexSet(integer: 9), toOffset: 0, in: base) == base)
    }

    @Test func removingRenumbersAndIgnoresABadIndex() {
        let base = day([bench, pecDeck, plank])
        let removed = RoutineEditor.remove(at: 1, from: base)
        #expect(removed.exercises.map(\.exercise) == [bench, plank] && removed.exercises.map(\.order) == [0, 1])
        #expect(RoutineEditor.remove(at: 3, from: base) == base)
        #expect(RoutineEditor.remove(at: -1, from: base) == base)
    }

    @Test func togglingASupersetPairsThenUnpairsTwoNeighbours() {
        let base = day([bench, pecDeck, plank])
        let paired = RoutineEditor.toggleSuperset(at: 1, in: base)
        #expect(paired.exercises.map(\.supersetGroup) == [nil, 1, 1])
        let unpaired = RoutineEditor.toggleSuperset(at: 1, in: paired)
        #expect(unpaired.exercises.map(\.supersetGroup) == [nil, nil, nil])
    }

    @Test func anExerciseAlreadyPairedCannotJoinAnotherPair() {
        let paired = RoutineEditor.toggleSuperset(at: 0, in: day([bench, pecDeck, plank]))
        #expect(RoutineEditor.toggleSuperset(at: 1, in: paired) == paired)
        #expect(RoutineEditor.toggleSuperset(at: 2, in: paired) == paired)
    }

    @Test func togglingOutOfBoundsChangesNothing() {
        let base = day([bench, pecDeck])
        #expect(RoutineEditor.toggleSuperset(at: 1, in: base) == base)
        #expect(RoutineEditor.toggleSuperset(at: -1, in: base) == base)
    }

    @Test func supersetGroupsAreRenumberedInOrder() {
        var base = day([bench, pecDeck, plank, bench, pecDeck])
        base = RoutineEditor.toggleSuperset(at: 3, in: base)
        base = RoutineEditor.toggleSuperset(at: 0, in: base)
        #expect(base.exercises.map(\.supersetGroup) == [1, 1, nil, 2, 2])
        let removed = RoutineEditor.remove(at: 0, from: base)
        #expect(removed.exercises.map(\.supersetGroup) == [nil, nil, 1, 1])
    }

    @Test func movingAnExerciseBreaksASupersetThatIsNoLongerConsecutive() {
        let paired = RoutineEditor.toggleSuperset(at: 0, in: day([bench, pecDeck, plank]))
        let moved = RoutineEditor.move(fromOffsets: IndexSet(integer: 0), toOffset: 3, in: paired)
        #expect(moved.exercises.map(\.exercise) == [pecDeck, plank, bench])
        #expect(moved.exercises.map(\.supersetGroup) == [nil, nil, nil])
        let swapped = RoutineEditor.move(fromOffsets: IndexSet(integer: 1), toOffset: 0, in: paired)
        #expect(swapped.exercises.map(\.supersetGroup) == [1, 1, nil])
    }

    @Test func settingSetsGrowsAndShrinksThePerSetTargets() throws {
        var day = RoutineEditor.setPerSetTargets(true, at: 0, in: day([bench]))
        day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 2, at: 0, in: day)
        day = RoutineEditor.setSets(5, at: 0, in: day)
        #expect(day.exercises[0].sets == 5 && day.exercises[0].setTargets?.count == 5)
        #expect(day.exercises[0].setTargets?.last == SetTarget(repsMin: 4, repsMax: 6))
        day = RoutineEditor.setSets(2, at: 0, in: day)
        #expect(day.exercises[0].setTargets == Array(repeating: SetTarget(repsMin: 8, repsMax: 12), count: 2))
        #expect(day.exercises[0].repsMin == 8 && day.exercises[0].repsMax == 12)
    }

    @Test func settingSetsWithoutPerSetTargetsOnlyChangesTheCount() {
        let day = RoutineEditor.setSets(4, at: 0, in: day([bench]))
        #expect(day.exercises[0].sets == 4 && day.exercises[0].setTargets == nil)
        #expect(RoutineEditor.setSets(0, at: 0, in: day).exercises[0].sets == 1)
        #expect(RoutineEditor.setSets(4, at: 5, in: day) == day)
    }

    @Test func perSetTargetsFollowTheSetCount() {
        var day = RoutineEditor.add([.content(id: "bench-press-barbell")], to: emptyDay, directory: directory)
        day = RoutineEditor.setPerSetTargets(true, at: 0, in: day)
        day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 1, at: 0, in: day)
        day = RoutineEditor.setSets(4, at: 0, in: day)
        #expect(day.exercises[0].setTargets == [SetTarget(repsMin: 8, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6),
                                                SetTarget(repsMin: 4, repsMax: 6), SetTarget(repsMin: 4, repsMax: 6)])
        #expect(day.exercises[0].repsMin == 4 && day.exercises[0].repsMax == 12)
    }

    @Test func disablingPerSetTargetsKeepsTheWidestRange() {
        var day = RoutineEditor.setPerSetTargets(true, at: 0, in: day([bench]))
        day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 3, repsMax: 5), set: 2, at: 0, in: day)
        #expect(day.exercises[0].repsMin == 3 && day.exercises[0].repsMax == 12)
        day = RoutineEditor.setPerSetTargets(false, at: 0, in: day)
        #expect(day.exercises[0].setTargets == nil)
        #expect(day.exercises[0].repsMin == 3 && day.exercises[0].repsMax == 12)
        #expect(RoutineEditor.setPerSetTargets(false, at: 0, in: day) == day)
    }

    @Test func enablingTwiceKeepsTheEditedTargets() {
        var day = RoutineEditor.setPerSetTargets(true, at: 0, in: day([bench]))
        day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 3, repsMax: 5), set: 0, at: 0, in: day)
        #expect(RoutineEditor.setPerSetTargets(true, at: 0, in: day) == day)
    }

    @Test func aTargetIsFollowedOnlyByLaterSetsThatSharedItsOldRange() {
        var day = RoutineEditor.setSets(4, at: 0, in: RoutineEditor.setPerSetTargets(true, at: 0, in: day([bench])))
        day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 2, at: 0, in: day)
        #expect(day.exercises[0].setTargets?.map(\.repsMin) == [8, 8, 4, 4])
        day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 10, repsMax: 12), set: 0, at: 0, in: day)
        #expect(day.exercises[0].setTargets == [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 10, repsMax: 12),
                                                SetTarget(repsMin: 4, repsMax: 6), SetTarget(repsMin: 4, repsMax: 6)])
        #expect(day.exercises[0].repsMin == 4 && day.exercises[0].repsMax == 12)
    }

    @Test func anInvertedTargetIsSwappedNeverTrapping() {
        var day = RoutineEditor.setPerSetTargets(true, at: 0, in: day([bench]))
        day = RoutineEditor.updateSetTarget(SetTarget(repsMin: 10, repsMax: 6), set: 1, at: 0, in: day)
        #expect(day.exercises[0].setTargets?[1] == SetTarget(repsMin: 6, repsMax: 10))
        #expect(day.exercises[0].repRange(forSet: 1) == 6...10)
        #expect(day.exercises[0].repsMin <= day.exercises[0].repsMax)
    }

    @Test func updatingASetWithoutPerSetTargetsOrOutOfRangeChangesNothing() {
        let plain = day([bench])
        #expect(RoutineEditor.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 0, at: 0, in: plain) == plain)
        let perSet = RoutineEditor.setPerSetTargets(true, at: 0, in: plain)
        #expect(RoutineEditor.updateSetTarget(SetTarget(repsMin: 4, repsMax: 6), set: 3, at: 0, in: perSet) == perSet)
    }
}
