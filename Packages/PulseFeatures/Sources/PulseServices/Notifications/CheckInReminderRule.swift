import Foundation
import PulseDomain

/// Les trois réponses rapides du rappel de check-in, actionnables depuis la notification, et le check-in que chacune enregistre.
public enum CheckInQuickAnswer: String, Sendable, CaseIterable {
    case good
    case average
    case tired

    /// « En forme » : 3 partout (score 75). « Moyen » : 2 partout (50). « Fatigué » : sommeil et motivation à 1, sans rien dire
    /// des courbatures (2) (34).
    public var answers: CheckInAnswers {
        switch self {
        case .good: CheckInAnswers(sleep: 3, pain: 3, motivation: 3)
        case .average: CheckInAnswers(sleep: 2, pain: 2, motivation: 2)
        case .tired: CheckInAnswers(sleep: 1, pain: 2, motivation: 1)
        }
    }

    public var title: String {
        switch self {
        case .good: String(localized: "En forme", bundle: .module)
        case .average: String(localized: "Moyen", bundle: .module)
        case .tired: String(localized: "Fatigué", bundle: .module)
        }
    }
}

/// Le réglage du rappel de check-in, gardé par appareil : actif par défaut (il ne part que sans données de montre), au réveil
/// habituel sauf heure choisie.
public struct CheckInReminderSettings: Sendable, Equatable {
    public var enabled: Bool
    /// L'heure choisie, en minutes après minuit ; `nil` : au réveil habituel.
    public var chosenMinutes: Int?

    public init(enabled: Bool = true, chosenMinutes: Int? = nil) {
        self.enabled = enabled
        self.chosenMinutes = chosenMinutes
    }
}

/// Ce que le rappel lit du jour : les données de montre, le check-in ou le score mesuré du jour, et les réveils habituels.
public struct CheckInReminderContext: Sendable, Equatable {
    /// Le dernier échantillon de VFC ou de FC au repos ; `nil` sans aucun.
    public var lastWatchSample: Date?
    public var onboardingCompletedAt: Date?
    /// Vrai si aujourd'hui a déjà un check-in ou un score mesuré.
    public var doneToday: Bool
    /// Le réveil habituel (ou choisi dans Sommeil) en semaine et le week-end, en minutes après minuit.
    public var weekdayWake: Int?
    public var weekendWake: Int?

    public init(lastWatchSample: Date?, onboardingCompletedAt: Date?, doneToday: Bool, weekdayWake: Int? = nil,
                weekendWake: Int? = nil) {
        self.lastWatchSample = lastWatchSample
        self.onboardingCompletedAt = onboardingCompletedAt
        self.doneToday = doneToday
        self.weekdayWake = weekdayWake
        self.weekendWake = weekendWake
    }
}

/// Quand demander « Comment tu te sens ? » à qui n'a pas de montre : sans VFC ni FC au repos, le score du jour passe par le
/// check-in, et la notification du matin (score mesuré seulement) ne part jamais.
public enum CheckInReminderRule {
    /// Les jours sans donnée de montre après lesquels le rappel se propose.
    public static let silentWatchDays = 3
    /// Les matins planifiés d'avance : sans ouvrir l'app, les rappels continuent une semaine.
    public static let horizonDays = 7
    /// 8 h, sans réveil habituel connu.
    public static let defaultMinutes = 8 * 60
    /// Les heures qu'on peut choisir : de 5 h à 11 h, par demi-heure.
    public static let choices = Array(stride(from: 5 * 60, through: 11 * 60, by: 30))

    public static var title: String { String(localized: "Comment tu te sens ?", bundle: .module) }
    public static var body: String { String(localized: "Réponds d'un geste : Pulse estime ton score du jour.", bundle: .module) }

    /// Vrai quand aucune donnée de montre n'est arrivée depuis `silentWatchDays` jours, comptés au plus tôt depuis la fin de
    /// l'onboarding : un nouveau profil a le temps de recevoir les premières mesures. Faux tant que l'onboarding n'est pas fini.
    public static func isOffered(lastWatchSample: Date?, onboardingCompletedAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let onboardingCompletedAt else { return false }
        let reference = max(lastWatchSample ?? onboardingCompletedAt, onboardingCompletedAt)
        let silent = calendar.dateComponents([.day], from: calendar.startOfDay(for: reference), to: calendar.startOfDay(for: now))
        return (silent.day ?? 0) >= silentWatchDays
    }

    /// Un rappel par matin des `horizonDays` jours à venir, à l'heure choisie, sinon au réveil habituel, sinon à 8 h ; aucun si
    /// le réglage est coupé ou le rappel pas proposé. Aujourd'hui n'en a pas si le check-in ou un score mesuré existe déjà, ni
    /// si l'heure est passée.
    public static func reminders(settings: CheckInReminderSettings, context: CheckInReminderContext, now: Date,
                                 calendar: Calendar) -> [CheckInReminder] {
        guard settings.enabled,
              isOffered(lastWatchSample: context.lastWatchSample, onboardingCompletedAt: context.onboardingCompletedAt, now: now,
                        calendar: calendar) else { return [] }
        let today = calendar.startOfDay(for: now)
        return (0..<horizonDays).compactMap { offset -> CheckInReminder? in
            guard offset > 0 || !context.doneToday,
                  let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let weekday = Weekday(date: day, calendar: calendar)
            let wake = weekday == .saturday || weekday == .sunday ? context.weekendWake : context.weekdayWake
            let minutes = settings.chosenMinutes ?? wake ?? defaultMinutes
            guard let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                  fire > now else { return nil }
            return CheckInReminder(day: day, fireDate: fire, title: title, body: body)
        }
    }
}
