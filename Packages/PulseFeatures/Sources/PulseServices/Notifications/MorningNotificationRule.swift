import Foundation
import PulseDomain

/// Quand annoncer le score du matin, et avec quel texte.
public enum MorningNotificationRule {
    /// 10 h, en minutes après minuit.
    public static let defaultDeadlineMinutes = 600

    private static let dayStartHour = 4

    // swiftlint:disable function_parameter_count
    /// Un message seulement si le score est mesuré et du jour, la préférence active, l'app pas ouverte depuis 4 h,
    /// pas déjà annoncé aujourd'hui, et `now` avant l'heure plafond.
    public static func message(recovery: DailyRecovery, session: TodaySession, profile: UserProfile, lastOpenedAt: Date?,
                               lastNotifiedDay: Date?, now: Date, calendar: Calendar) -> MorningScoreMessage? {
        guard !recovery.isEstimated, profile.morningScoreNotification,
              calendar.isDate(recovery.day, inSameDayAs: now) else { return nil }
        if let lastNotifiedDay, calendar.isDate(lastNotifiedDay, inSameDayAs: now) { return nil }
        // Heures de l'horloge locale, pas des durées depuis minuit : les jours de changement d'heure en dépendent.
        if let lastOpenedAt, let openedSince = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: now),
           lastOpenedAt >= openedSince { return nil }
        let deadlineMinutes = profile.morningScoreDeadlineMinutes ?? defaultDeadlineMinutes
        guard let deadline = calendar.date(bySettingHour: deadlineMinutes / 60, minute: deadlineMinutes % 60, second: 0, of: now),
              now < deadline else { return nil }
        let score = Int(recovery.score.rounded())
        let sentence = "\(score) · \(recovery.category.sentenceName)"
        let body = session.isLightened ? String(localized: "\(sentence), séance allégée", bundle: .module) : sentence
        return MorningScoreMessage(title: String(localized: "Ton score du matin est prêt", bundle: .module), body: body)
    }
    // swiftlint:enable function_parameter_count
}
