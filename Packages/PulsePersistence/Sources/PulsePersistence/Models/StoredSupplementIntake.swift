import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredSupplementIntake {
    public var id: UUID = UUID()
    public var supplementID: UUID = UUID()
    public var takenAt: Date = Date()
    public var dose: Double = 0
    public var writtenToHealthKit: Bool = false
    public var healthKitUUID: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ intake: SupplementIntake) {
        id = intake.id
        createdAt = intake.createdAt
        apply(intake)
    }

    public func apply(_ intake: SupplementIntake) {
        supplementID = intake.supplementID
        takenAt = intake.takenAt
        dose = intake.dose
        writtenToHealthKit = intake.writtenToHealthKit
        healthKitUUID = intake.healthKitUUID
        updatedAt = intake.updatedAt
    }

    public func toDomain() -> SupplementIntake {
        SupplementIntake(id: id, supplementID: supplementID, takenAt: takenAt, dose: dose, writtenToHealthKit: writtenToHealthKit,
                         healthKitUUID: healthKitUUID, createdAt: createdAt, updatedAt: updatedAt)
    }
}
