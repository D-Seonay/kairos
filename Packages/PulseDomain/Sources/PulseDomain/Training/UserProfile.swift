import Foundation

public enum Sex: String, Sendable, Codable, CaseIterable {
    case female
    case male
    case unspecified
}

public enum TrainingLevel: String, Sendable, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

public enum Weekday: String, Sendable, Codable, CaseIterable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
}

public enum EquipmentAccess: String, Sendable, Codable, CaseIterable {
    case fullGym
    case homeGym
    case bodyweight
}

public enum PainArea: String, Sendable, Codable, CaseIterable {
    case shoulders
    case lowerBack
    case knees
    case wrists
}

public enum WeightUnit: String, Sendable, Codable, CaseIterable {
    case kg
    case lb
}

/// Règles anti-interférence de la spec V1 §6.5, chacune désactivable.
public enum AntiInterferenceRule: String, Sendable, Codable, CaseIterable {
    case noIntenseRunAfterHeavyLegs
    case sameDayOrdering
    case fullRestDay
}

public enum Theme: String, Sendable, Codable, CaseIterable {
    case amber
    case amethyst
}

/// Le profil de l'utilisateur, un seul enregistrement (spec M2 §5.3). `focus` : 0 = force, 1 = endurance.
public struct UserProfile: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    /// Prénom saisi à l'accueil, utilisé pour les salutations. Nul tant qu'il n'est pas renseigné.
    public var firstName: String?
    public var sex: Sex
    public var birthDate: Date?
    public var heightCm: Double?
    public var weightKg: Double?
    public var strengthLevel: TrainingLevel
    public var runningLevel: TrainingLevel
    public var focus: Double
    public var trainingDaysPerWeek: Int
    public var restWeekdays: [Weekday]
    public var equipmentAccess: EquipmentAccess
    public var painAreas: [PainArea]
    public var weightUnit: WeightUnit
    public var adaptationEnabled: Bool
    public var antiInterferenceRulesDisabled: [AntiInterferenceRule]
    public var upperIncrementKg: Double
    public var lowerIncrementKg: Double
    public var barWeightKg: Double
    public var availablePlatesKg: [Double]
    public var defaultRestSeconds: Int
    public var autoWarmupEnabled: Bool
    public var theme: Theme
    public var morningScoreNotification: Bool
    public var morningScoreDeadlineMinutes: Int?
    public var supplementRemindersEnabled: Bool
    public var restTimerNotificationEnabled: Bool
    public var onboardingCompletedAt: Date?
    public var activeProgramID: UUID?
    public var deloadWeekStartedAt: Date?
    public var deloadDeclinedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        firstName: String? = nil,
        sex: Sex = .unspecified,
        birthDate: Date? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        strengthLevel: TrainingLevel = .beginner,
        runningLevel: TrainingLevel = .beginner,
        focus: Double = 0.5,
        trainingDaysPerWeek: Int = 3,
        restWeekdays: [Weekday] = [],
        equipmentAccess: EquipmentAccess = .fullGym,
        painAreas: [PainArea] = [],
        weightUnit: WeightUnit = .kg,
        adaptationEnabled: Bool = true,
        antiInterferenceRulesDisabled: [AntiInterferenceRule] = [],
        upperIncrementKg: Double = 2.5,
        lowerIncrementKg: Double = 5,
        barWeightKg: Double = 20,
        availablePlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25],
        defaultRestSeconds: Int = 90,
        autoWarmupEnabled: Bool = true,
        theme: Theme = .amber,
        morningScoreNotification: Bool = true,
        morningScoreDeadlineMinutes: Int? = nil,
        supplementRemindersEnabled: Bool = true,
        restTimerNotificationEnabled: Bool = true,
        onboardingCompletedAt: Date? = nil,
        activeProgramID: UUID? = nil,
        deloadWeekStartedAt: Date? = nil,
        deloadDeclinedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.sex = sex
        self.birthDate = birthDate
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.strengthLevel = strengthLevel
        self.runningLevel = runningLevel
        self.focus = focus
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.restWeekdays = restWeekdays
        self.equipmentAccess = equipmentAccess
        self.painAreas = painAreas
        self.weightUnit = weightUnit
        self.adaptationEnabled = adaptationEnabled
        self.antiInterferenceRulesDisabled = antiInterferenceRulesDisabled
        self.upperIncrementKg = upperIncrementKg
        self.lowerIncrementKg = lowerIncrementKg
        self.barWeightKg = barWeightKg
        self.availablePlatesKg = availablePlatesKg
        self.defaultRestSeconds = defaultRestSeconds
        self.autoWarmupEnabled = autoWarmupEnabled
        self.theme = theme
        self.morningScoreNotification = morningScoreNotification
        self.morningScoreDeadlineMinutes = morningScoreDeadlineMinutes
        self.supplementRemindersEnabled = supplementRemindersEnabled
        self.restTimerNotificationEnabled = restTimerNotificationEnabled
        self.onboardingCompletedAt = onboardingCompletedAt
        self.activeProgramID = activeProgramID
        self.deloadWeekStartedAt = deloadWeekStartedAt
        self.deloadDeclinedAt = deloadDeclinedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
