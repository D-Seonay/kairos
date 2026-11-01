import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredProfile {
    public var id: UUID = UUID()
    public var sex: String = Sex.unspecified.rawValue
    public var birthDate: Date?
    public var heightCm: Double?
    public var weightKg: Double?
    public var strengthLevel: String = TrainingLevel.beginner.rawValue
    public var runningLevel: String = TrainingLevel.beginner.rawValue
    public var focus: Double = 0.5
    public var trainingDaysPerWeek: Int = 3
    public var restWeekdays: Data?
    public var equipmentAccess: String = EquipmentAccess.fullGym.rawValue
    public var painAreas: Data?
    public var weightUnit: String = WeightUnit.kg.rawValue
    public var adaptationEnabled: Bool = true
    public var antiInterferenceRulesDisabled: Data?
    public var upperIncrementKg: Double = 2.5
    public var lowerIncrementKg: Double = 5
    public var barWeightKg: Double = 20
    public var availablePlatesKg: Data?
    public var defaultRestSeconds: Int = 90
    public var autoWarmupEnabled: Bool = true
    public var theme: String = Theme.amber.rawValue
    public var morningScoreNotification: Bool = true
    public var morningScoreDeadlineMinutes: Int?
    public var supplementRemindersEnabled: Bool = true
    public var restTimerNotificationEnabled: Bool = true
    public var onboardingCompletedAt: Date?
    public var activeProgramID: UUID?
    public var deloadWeekStartedAt: Date?
    public var deloadDeclinedAt: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ profile: UserProfile) {
        id = profile.id
        createdAt = profile.createdAt
        apply(profile)
    }

    /// Recopie tous les champs sauf `id` et `createdAt`.
    public func apply(_ profile: UserProfile) {
        sex = profile.sex.rawValue
        birthDate = profile.birthDate
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        strengthLevel = profile.strengthLevel.rawValue
        runningLevel = profile.runningLevel.rawValue
        focus = profile.focus
        trainingDaysPerWeek = profile.trainingDaysPerWeek
        restWeekdays = CodableColumn.encode(profile.restWeekdays)
        equipmentAccess = profile.equipmentAccess.rawValue
        painAreas = CodableColumn.encode(profile.painAreas)
        weightUnit = profile.weightUnit.rawValue
        adaptationEnabled = profile.adaptationEnabled
        antiInterferenceRulesDisabled = CodableColumn.encode(profile.antiInterferenceRulesDisabled)
        upperIncrementKg = profile.upperIncrementKg
        lowerIncrementKg = profile.lowerIncrementKg
        barWeightKg = profile.barWeightKg
        availablePlatesKg = CodableColumn.encode(profile.availablePlatesKg)
        defaultRestSeconds = profile.defaultRestSeconds
        autoWarmupEnabled = profile.autoWarmupEnabled
        theme = profile.theme.rawValue
        morningScoreNotification = profile.morningScoreNotification
        morningScoreDeadlineMinutes = profile.morningScoreDeadlineMinutes
        supplementRemindersEnabled = profile.supplementRemindersEnabled
        restTimerNotificationEnabled = profile.restTimerNotificationEnabled
        onboardingCompletedAt = profile.onboardingCompletedAt
        activeProgramID = profile.activeProgramID
        deloadWeekStartedAt = profile.deloadWeekStartedAt
        deloadDeclinedAt = profile.deloadDeclinedAt
        updatedAt = profile.updatedAt
    }

    public func toDomain() -> UserProfile {
        UserProfile(
            id: id, sex: .stored(sex, default: .unspecified), birthDate: birthDate, heightCm: heightCm, weightKg: weightKg,
            strengthLevel: .stored(strengthLevel, default: .beginner), runningLevel: .stored(runningLevel, default: .beginner),
            focus: focus, trainingDaysPerWeek: trainingDaysPerWeek,
            restWeekdays: CodableColumn.decode([Weekday].self, from: restWeekdays, default: []),
            equipmentAccess: .stored(equipmentAccess, default: .fullGym),
            painAreas: CodableColumn.decode([PainArea].self, from: painAreas, default: []),
            weightUnit: .stored(weightUnit, default: .kg), adaptationEnabled: adaptationEnabled,
            antiInterferenceRulesDisabled: CodableColumn.decode([AntiInterferenceRule].self, from: antiInterferenceRulesDisabled,
                                                                default: []),
            upperIncrementKg: upperIncrementKg, lowerIncrementKg: lowerIncrementKg, barWeightKg: barWeightKg,
            availablePlatesKg: CodableColumn.decode([Double].self, from: availablePlatesKg, default: []),
            defaultRestSeconds: defaultRestSeconds, autoWarmupEnabled: autoWarmupEnabled, theme: .stored(theme, default: .amber),
            morningScoreNotification: morningScoreNotification, morningScoreDeadlineMinutes: morningScoreDeadlineMinutes,
            supplementRemindersEnabled: supplementRemindersEnabled, restTimerNotificationEnabled: restTimerNotificationEnabled,
            onboardingCompletedAt: onboardingCompletedAt, activeProgramID: activeProgramID,
            deloadWeekStartedAt: deloadWeekStartedAt, deloadDeclinedAt: deloadDeclinedAt, createdAt: createdAt, updatedAt: updatedAt)
    }
}
