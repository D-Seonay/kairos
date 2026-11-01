import Foundation
@testable import PulseDomain
import Testing

@Test func exerciseReferenceEncodesReadably() throws {
    let content = String(bytes: try JSONEncoder().encode(ExerciseReference.content(id: "plank")), encoding: .utf8)
    #expect(content == #"{"content":"plank"}"#)
    let uuid = UUID()
    let user = try JSONDecoder().decode(ExerciseReference.self, from: Data(#"{"user":"\#(uuid.uuidString)"}"#.utf8))
    #expect(user == .user(id: uuid))
    let userText = String(bytes: try JSONEncoder().encode(user), encoding: .utf8)
    #expect(userText == #"{"user":"\#(uuid.uuidString)"}"#)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(ExerciseReference.self, from: Data(#"{"other":"x"}"#.utf8))
    }
}

@Test func exerciseReferenceColumns() {
    let uuid = UUID()
    #expect(ExerciseReference(contentID: "plank", userID: nil) == .content(id: "plank"))
    #expect(ExerciseReference(contentID: nil, userID: uuid) == .user(id: uuid))
    #expect(ExerciseReference(contentID: nil, userID: nil) == nil)
    #expect(ExerciseReference(contentID: "a", userID: uuid) == nil)
    #expect(ExerciseReference.content(id: "plank").contentID == "plank")
    #expect(ExerciseReference.content(id: "plank").userID == nil)
    #expect(ExerciseReference.user(id: uuid).userID == uuid)
}
