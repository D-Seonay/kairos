import Foundation

/// Une série de l'export Hevy, avec la séance et l'exercice qui la portent. Un champ vide de l'export devient `nil`.
public struct HevyRow: Sendable, Equatable {
    public let title: String
    public let startedAt: Date
    public let endedAt: Date
    public let description: String?
    public let exerciseTitle: String
    public let supersetID: Int?
    public let exerciseNotes: String?
    public let setIndex: Int
    public let setType: String
    public let weightKg: Double?
    public let reps: Int?
    public let distanceKm: Double?
    public let durationSeconds: Int?
    public let rpe: Double?
}
