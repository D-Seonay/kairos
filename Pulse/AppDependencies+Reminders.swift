import Foundation
import PulseDomain
import PulsePersistence
import PulseServices
import SwiftData

// MARK: - Compléments, coucher et réglages

extension AppDependencies {
    /// Le dépôt des compléments et leur service, avec les rappels et l'écriture Apple Santé du câblage. Le service lit le profil,
    /// le programme et la semaine datée du passage du jour, les séances sans doublons, et les nuits du cache local d'Apple Santé
    /// pour les compléments « au coucher » qui les suivent (réglage gardé dans la suite de préférences que la suppression vide).
    static func makeSupplements(_ wiring: Wiring, container: ModelContainer, stores: RefresherStores,
                                workouts: any WorkoutRepository) -> (SwiftDataSupplementRepository, SupplementService) {
        let supplements = SwiftDataSupplementRepository(modelContainer: container)
        let service = SupplementService(
            supplements: supplements, programs: stores.programs, profiles: stores.profiles, workouts: workouts,
            reminders: wiring.supplementReminders, health: wiring.supplementHealth, scheduledDays: stores.scheduledDays,
            bedtime: HabitualBedtimeReader(cache: stores.healthCache, calendar: wiring.calendar),
            bedtimeStore: UserDefaultsSupplementBedtimeStore(suiteName: wiring.defaultsSuite),
            calendar: wiring.calendar, now: wiring.now)
        return (supplements, service)
    }

    /// Les réglages du profil, et les rappels de coucher qu'ils replanifient. Les rappels de compléments, ceux du coucher et
    /// l'ambiance des widgets dépendent d'un réglage enregistré : le score du matin, la fin du repos et le moteur relisent le
    /// profil à chaque fois. Le service des rappels de coucher lit le profil, le programme et la semaine datée du passage du
    /// jour, et les nuits du cache local d'Apple Santé, avec le planificateur du câblage.
    static func makeSettings(_ wiring: Wiring, stores: RefresherStores,
                             supplementService: SupplementService) -> (SettingsService, BedtimeReminderService) {
        let bedtime = BedtimeReminderService(
            profiles: stores.profiles, programs: stores.programs, scheduledDays: stores.scheduledDays,
            bedtime: HabitualBedtimeReader(cache: stores.healthCache, calendar: wiring.calendar),
            reminders: wiring.bedtimeReminders, calendar: wiring.calendar, now: wiring.now)
        let widgets = wiring.widgets
        let settings = SettingsService(profiles: stores.profiles, now: wiring.now) { old, new in
            if old.theme != new.theme { await widgets.publishTheme(new.theme) }
            if old.supplementRemindersEnabled != new.supplementRemindersEnabled { await supplementService.rescheduleReminders() }
            if SleepPlan.settingsChanged(from: old, to: new) { await bedtime.reschedule() }
        }
        return (settings, bedtime)
    }
}
