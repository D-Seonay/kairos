import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredSupplement {
    public var id: UUID = UUID()
    public var name: String = ""
    public var form: String = SupplementForm.powder.rawValue
    public var dose: Double = 0
    public var unit: String = DoseUnit.gram.rawValue
    public var timing: String = SupplementTiming.fixedTime.rawValue
    public var timeOfDayMinutes: Int?
    public var days: String = SupplementDays.everyDay.rawValue
    public var customWeekdays: Data?
    public var stockDoses: Double?
    public var lowStockThreshold: Double?
    public var reminderEnabled: Bool = false
    public var healthKitType: String?
    public var isArchived: Bool = false
    public var order: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ supplement: Supplement) {
        id = supplement.id
        createdAt = supplement.createdAt
        apply(supplement)
    }

    public func apply(_ supplement: Supplement) {
        name = supplement.name
        form = supplement.form.rawValue
        dose = supplement.dose
        unit = supplement.unit.rawValue
        timing = supplement.timing.rawValue
        timeOfDayMinutes = supplement.timeOfDayMinutes
        days = supplement.days.rawValue
        customWeekdays = CodableColumn.encode(supplement.customWeekdays)
        stockDoses = supplement.stockDoses
        lowStockThreshold = supplement.lowStockThreshold
        reminderEnabled = supplement.reminderEnabled
        healthKitType = supplement.healthKitType
        isArchived = supplement.isArchived
        order = supplement.order
        updatedAt = supplement.updatedAt
    }

    public func toDomain() -> Supplement {
        Supplement(id: id, name: name, form: .stored(form, default: .powder), dose: dose, unit: .stored(unit, default: .gram),
                   timing: .stored(timing, default: .fixedTime), timeOfDayMinutes: timeOfDayMinutes,
                   days: .stored(days, default: .everyDay),
                   customWeekdays: CodableColumn.decode([Weekday].self, from: customWeekdays, default: []), stockDoses: stockDoses,
                   lowStockThreshold: lowStockThreshold, reminderEnabled: reminderEnabled, healthKitType: healthKitType,
                   isArchived: isArchived, order: order, createdAt: createdAt, updatedAt: updatedAt)
    }
}
