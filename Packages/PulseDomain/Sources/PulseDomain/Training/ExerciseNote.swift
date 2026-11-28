import Foundation

/// Note libre sur un exercice, prise pendant une séance.
public struct ExerciseNote: Sendable, Equatable, Codable {
    public var exercise: ExerciseReference
    public var text: String

    public init(exercise: ExerciseReference, text: String) {
        self.exercise = exercise
        self.text = text
    }
}

extension ExerciseNote {
    /// Les notes non vides de `exercise`, sans doublon, une par ligne dans l'ordre de la séance ; `nil` sans aucune. Un
    /// exercice présent deux fois dans la routine garde ainsi la note de chaque carte, et la séance suivante les reprend toutes.
    public static func merged(_ notes: [ExerciseNote], for exercise: ExerciseReference) -> String? {
        var texts: [String] = []
        for note in notes where note.exercise == exercise {
            let text = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty && !texts.contains(text) { texts.append(text) }
        }
        return texts.isEmpty ? nil : texts.joined(separator: "\n")
    }
}
