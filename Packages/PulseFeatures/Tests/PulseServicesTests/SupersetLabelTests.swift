import PulseServices
import Testing

struct SupersetLabelTests {
    private typealias Fix = LiveFixtures

    @Test func membersGetTheirGroupLetterAndPlace() {
        #expect(SupersetLabel.labels(for: [nil, 3, 3, 3, nil, 7, 7]) == [nil, "A1", "A2", "A3", nil, "B1", "B2"])
    }

    @Test func aLoneMemberOrASplitGroupGetsNoLabelForTheLoneOne() {
        #expect(SupersetLabel.labels(for: [1, nil, 1, 1]) == [nil, nil, "A1", "A2"])
        #expect(SupersetLabel.labels(for: []) == [])
    }

    @Test func lettersRunOutIntoNumbers() {
        #expect(SupersetLabel.letter(0) == "A" && SupersetLabel.letter(25) == "Z" && SupersetLabel.letter(26) == "27")
    }

    @Test func aLiveSessionLabelsItsExercisesByID() {
        let day = Fix.day([Fix.exercise(Fix.bench, order: 0, superset: 1), Fix.exercise(Fix.pecDeck, order: 1, superset: 1),
                           Fix.exercise(Fix.pullUp, order: 2, superset: 1), Fix.exercise(Fix.plank, order: 3, reps: 30...60)])
        let session = Fix.session(Fix.launch(day, nil))
        #expect(session.exercises.map { session.supersetLabel(of: $0.id) } == ["A1", "A2", "A3", nil])
    }
}
