import Foundation

/// Réglages de l'utilisateur pour un exercice : incrément de charge et nombre de séries d'échauffement.
/// `nil` signifie « garder la valeur par défaut de l'exercice ».
public struct ExerciseSettings: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var exercise: ExerciseReference
    public var incrementKg: Double?
    public var warmupSetCount: Int?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), exercise: ExerciseReference, incrementKg: Double? = nil, warmupSetCount: Int? = nil,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.exercise = exercise
        self.incrementKg = incrementKg
        self.warmupSetCount = warmupSetCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
