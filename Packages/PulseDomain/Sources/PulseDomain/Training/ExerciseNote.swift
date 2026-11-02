/// Note libre sur un exercice, prise pendant une séance.
public struct ExerciseNote: Sendable, Equatable, Codable {
    public var exercise: ExerciseReference
    public var text: String

    public init(exercise: ExerciseReference, text: String) {
        self.exercise = exercise
        self.text = text
    }
}
