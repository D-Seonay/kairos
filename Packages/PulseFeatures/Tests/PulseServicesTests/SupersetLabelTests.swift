import PulseServices
import Testing

struct SupersetLabelTests {
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
}
