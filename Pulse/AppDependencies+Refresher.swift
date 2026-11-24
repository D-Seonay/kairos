import Foundation
import PulseDomain
import PulseServices

extension AppDependencies {
    /// Les dépôts que lit le passage du jour.
    struct RefresherStores {
        var profiles: any ProfileRepository
        var programs: any ProgramRepository
        var recovery: any RecoveryRepository
        /// Le dépôt brut, doublons compris : celui de `WorkoutHistory`. Les règles anti-interférence lisent les séances sans eux.
        var storedWorkouts: any WorkoutRepository
        var scheduledDays: any ScheduledDayRepository
        var userExercises: any UserExerciseRepository
        var bodyMeasurements: any BodyMeasurementRepository
        var healthCache: any HealthSampleCache
        var activity: any DayActivityLog
        var planning: PlanningService
        var relocation: any HealthDataRelocating
    }

    /// Le passage du jour : les nuits, puis les courses et les vélos quand la source Apple Santé sait les lire (spec M6 §3), le
    /// poids et la masse grasse (spec M7 §14), les règles anti-interférence (§9), et la série et la semaine publiées avec
    /// l'instantané du widget (§11).
    static func makeRefresher(_ wiring: Wiring, stores: RefresherStores, scores: DailyScoreService) -> DayRefresher {
        let calendar = wiring.calendar
        let workouts = DeduplicatingWorkoutRepository(base: stores.storedWorkouts)
        let workoutHistory = (wiring.healthSource as? any HealthWorkoutSource).map { source in
            // Le dépôt brut : les séances importées doivent rester visibles pour être alignées, doublons compris. Les entraînements
            // que Pulse a écrits dans Apple Santé ne sont pas réimportés.
            WorkoutHistory(source: source, cache: stores.healthCache, workouts: stores.storedWorkouts, profiles: stores.profiles,
                           windows: UserDefaultsHealthReadWindowStore(suiteName: wiring.defaultsSuite), calendar: calendar,
                           ownBundleIdentifier: Bundle.main.bundleIdentifier)
        }
        let bodyHistory = (wiring.healthSource as? any HealthBodySource).map { source in
            BodyHistory(source: source, cache: stores.healthCache, measurements: stores.bodyMeasurements,
                        profiles: stores.profiles, windows: UserDefaultsHealthReadWindowStore(suiteName: wiring.defaultsSuite),
                        calendar: calendar)
        }
        return DayRefresher(
            profiles: stores.profiles, programs: stores.programs, recovery: stores.recovery,
            nightHistory: NightHistory(source: wiring.healthSource, cache: stores.healthCache, calendar: calendar), scores: scores,
            widgets: wiring.widgets, notifications: wiring.morningScore, activity: stores.activity,
            scheduledDays: stores.scheduledDays, workoutHistory: workoutHistory, bodyHistory: bodyHistory,
            antiInterference: AntiInterferenceService(
                profiles: stores.profiles, programs: stores.programs, workouts: workouts, scheduledDays: stores.scheduledDays,
                userExercises: stores.userExercises, library: .bundled, calendar: calendar, now: wiring.now),
            planning: stores.planning, relocation: stores.relocation, calendar: calendar, now: wiring.now)
    }
}
