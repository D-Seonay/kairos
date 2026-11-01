import Foundation

/// Une prise horodatée d'un complément.
public struct SupplementIntake: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var supplementID: UUID
    public var takenAt: Date
    public var dose: Double
    public var writtenToHealthKit: Bool
    public var healthKitUUID: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), supplementID: UUID, takenAt: Date, dose: Double, writtenToHealthKit: Bool = false,
                healthKitUUID: String? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.supplementID = supplementID
        self.takenAt = takenAt
        self.dose = dose
        self.writtenToHealthKit = writtenToHealthKit
        self.healthKitUUID = healthKitUUID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
