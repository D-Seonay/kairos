import Foundation

public enum SupplementForm: String, Sendable, Codable, CaseIterable {
    case powder
    case capsule
    case tablet
    case liquid
}

public enum DoseUnit: String, Sendable, Codable, CaseIterable {
    case gram = "g"
    case mg
    case iu
    case ml
    case serving
}

public enum SupplementTiming: String, Sendable, Codable, CaseIterable {
    case fixedTime
    case beforeWorkout
    case afterWorkout
    case bedtime
}

public enum SupplementDays: String, Sendable, Codable, CaseIterable {
    case everyDay
    case trainingDays
    case custom
}

/// Un complément de l'utilisateur (spec V1 §5.3, champs spec M2 §5.3). Jamais de dose conseillée : la dose est la sienne.
public struct Supplement: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var form: SupplementForm
    public var dose: Double
    public var unit: DoseUnit
    public var timing: SupplementTiming
    public var timeOfDayMinutes: Int?
    public var days: SupplementDays
    public var customWeekdays: [Weekday]
    public var stockDoses: Double?
    public var lowStockThreshold: Double?
    public var reminderEnabled: Bool
    public var healthKitType: String?
    public var isArchived: Bool
    public var order: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, form: SupplementForm, dose: Double, unit: DoseUnit, timing: SupplementTiming,
                timeOfDayMinutes: Int? = nil, days: SupplementDays, customWeekdays: [Weekday] = [], stockDoses: Double? = nil,
                lowStockThreshold: Double? = nil, reminderEnabled: Bool = false, healthKitType: String? = nil,
                isArchived: Bool = false, order: Int, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.form = form
        self.dose = dose
        self.unit = unit
        self.timing = timing
        self.timeOfDayMinutes = timeOfDayMinutes
        self.days = days
        self.customWeekdays = customWeekdays
        self.stockDoses = stockDoses
        self.lowStockThreshold = lowStockThreshold
        self.reminderEnabled = reminderEnabled
        self.healthKitType = healthKitType
        self.isArchived = isArchived
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
