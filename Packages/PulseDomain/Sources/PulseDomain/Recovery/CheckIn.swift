import Foundation

/// Réponses du check-in du matin, chacune de 0 à 4, 4 étant le meilleur état.
public struct CheckInAnswers: Sendable, Equatable, Codable {
    public var sleep: Int
    public var pain: Int
    public var motivation: Int

    public init(sleep: Int, pain: Int, motivation: Int) {
        self.sleep = sleep
        self.pain = pain
        self.motivation = motivation
    }
}

/// Un check-in enregistré pour un jour, avec le score estimé qu'il a produit.
public struct CheckIn: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var day: Date
    public var answers: CheckInAnswers
    public var score: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), day: Date, answers: CheckInAnswers, score: Double, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.day = day
        self.answers = answers
        self.score = score
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
