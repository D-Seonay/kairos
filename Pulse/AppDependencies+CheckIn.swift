import Foundation
import PulseDomain
import PulseServices

// MARK: - Rappel de check-in

extension AppDependencies {
    /// Le rappel de check-in : son réglage dans la suite de préférences que la suppression vide, le profil, les check-ins et les
    /// scores, les mesures de montre et les nuits du cache local d'Apple Santé. Il est planifié par le planificateur des rappels du
    /// coucher quand celui-ci sait le faire (l'app réelle), par une doublure sinon (tests, modes des tests d'interface). Une
    /// réponse rapide passe par le passage du jour, comme le check-in de l'accueil.
    static func checkIns(_ wiring: Wiring, _ stores: RefresherStores, _ refresher: DayRefresher) -> CheckInReminderService {
        CheckInReminderService(
            store: UserDefaultsCheckInReminderStore(suiteName: wiring.defaultsSuite), profiles: stores.profiles,
            recovery: stores.recovery, cache: stores.healthCache,
            scheduler: (wiring.bedtimeReminders as? any CheckInReminderScheduling) ?? StubCheckInReminderScheduler(),
            notifications: wiring.notifications, saveCheckIn: { _ = try await refresher.saveCheckIn($0) },
            calendar: wiring.calendar, now: wiring.now)
    }
}
