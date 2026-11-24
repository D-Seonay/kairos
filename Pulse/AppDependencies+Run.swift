import Foundation
import PulseDomain
import PulseHealth
import PulsePersistence
import PulseServices
import RunFeature
import SwiftData

// MARK: - Course

extension AppDependencies {
    /// Les adaptateurs de la course, qui changent entre l'app réelle, les modes des tests d'interface et les tests.
    struct RunAdapters {
        var recorder: any RunWorkoutRecording
        /// Le même objet que `recorder` dans l'app réelle avec Apple Santé ; `nil` sinon.
        var healthSession: HealthKitRunRecorder?
        var location: any RunLocationTracking
        var announcer: any RunAnnouncing
        var activity: any RunActivityControlling
        var reminders: any RunReminderScheduling

        /// Sans séance HealthKit (Apple Santé absent, scénario de lancement), la course n'écrit rien dans Santé.
        static func live(healthSession: HealthKitRunRecorder?, reminders: any RunReminderScheduling) -> RunAdapters {
            RunAdapters(recorder: healthSession ?? StubRunWorkoutRecorder(access: .unavailable, grantedOnRequest: .unavailable),
                        healthSession: healthSession, location: CoreLocationRunTracker(), announcer: SpeechRunAnnouncer(),
                        activity: RunActivityController(), reminders: reminders)
        }

        /// Aucune localisation, voix, Live Activity, notification ni écriture Santé réelles.
        static var stubs: RunAdapters {
            RunAdapters(recorder: StubRunWorkoutRecorder(access: .unavailable, grantedOnRequest: .unavailable),
                        healthSession: nil, location: StubRunLocationTracker(), announcer: StubRunAnnouncer(),
                        activity: StubRunActivityController(), reminders: StubRunReminderScheduler())
        }
    }

    /// La course de l'app, assemblée une fois au lancement.
    struct RunDependencies: Sendable {
        /// Le seul chemin vers la course en cours : l'écran de course, le bandeau « Reprendre la course » et les boutons de la
        /// Live Activity de course.
        let service: RunSessionService
        /// Les tracés des courses Pulse, synchronisés : le récap et le détail d'une séance les lisent.
        let tracks: any RunTrackRepository
        /// Les annonces vocales, dans la suite de préférences que la suppression totale vide.
        let preferences: any RunPreferencesStore
        /// La séance HealthKit de la course, à qui `AppDelegate` remet celle que le système a gardée après un crash ; `nil` sans
        /// Apple Santé, avec un scénario de lancement, en mode mémoire et dans les tests.
        let healthSession: HealthKitRunRecorder?

        /// `workouts` masque les doublons de la montre : une course Pulse enregistrée garde en magasin la FC du direct.
        init(_ wiring: Wiring, container: ModelContainer, workouts: any WorkoutRepository, profiles: any ProfileRepository) {
            let adapters = wiring.run
            let tracks = SwiftDataRunTrackRepository(modelContainer: container)
            let preferences = UserDefaultsRunPreferencesStore(suiteName: wiring.defaultsSuite)
            service = RunSessionService(
                recorder: adapters.recorder, location: adapters.location, announcer: adapters.announcer,
                activity: adapters.activity, reminders: adapters.reminders,
                drafts: SwiftDataRunDraftStore(modelContainer: container), workouts: workouts, tracks: tracks,
                profiles: profiles, preferences: preferences, spokenText: RunText.spokenText(for:), now: wiring.now,
                calendar: wiring.calendar)
            self.tracks = tracks
            self.preferences = preferences
            healthSession = adapters.healthSession
        }
    }
}
