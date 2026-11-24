import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

/// Face ID qui réussit toujours : seule sa présence compte ici.
private struct AcceptingOwnerAuthentication: DeviceOwnerAuthenticating {
    func isAvailable() async -> Bool { true }
    func authenticate(reason: String) async -> Bool { true }
}

/// La ligne « Photos de corps » de Profil : elle n'apparaît qu'avec le service et l'authentificateur, jamais sans verrou.
struct ProfileBodyPhotosTests {
    private func environment(bodyPhotos: Bool, authentication: Bool) -> ProfileEnvironment {
        let calendar = ProfileTestClock.calendar
        let clock: @Sendable () -> Date = { ProfileTestClock.now }
        let profiles = InMemoryProfileRepository()
        let measurements = InMemoryBodyMeasurementRepository()
        let service = ProfileService(profiles: profiles, programs: InMemoryProgramRepository(), workouts: InMemoryWorkoutRepository(),
                                     recoveries: InMemoryRecoveryRepository(calendar: calendar),
                                     records: InMemoryPersonalRecordRepository(), userExercises: InMemoryUserExerciseRepository(),
                                     library: .bundled, calendar: calendar, now: clock)
        let photos = BodyPhotoService(store: InMemoryBodyPhotoStore(), measurements: measurements, calendar: calendar, now: clock)
        return ProfileEnvironment(
            profile: service, body: BodyService(measurements: measurements, profiles: profiles, calendar: calendar, now: clock),
            settings: SettingsService(profiles: profiles, now: clock) { _, _ in }, healthCache: InMemoryHealthSampleCache(),
            inspector: SilentInspector(), exporter: SilentExporter(), eraser: SilentEraser(), notificationStatus: { .authorized },
            requestNotificationAuthorization: { true }, refreshHealth: {}, appVersion: "1.0.2 (14)", privacyPolicyURL: nil,
            calendar: calendar, now: clock, bodyPhotos: bodyPhotos ? photos : nil,
            ownerAuthentication: authentication ? AcceptingOwnerAuthentication() : nil)
    }

    @Test func bodyPhotosAreOfferedWithTheServiceAndTheAuthenticator() {
        #expect(environment(bodyPhotos: true, authentication: true).offersBodyPhotos)
    }

    @Test func bodyPhotosAreHiddenWithoutAnAuthenticator() {
        #expect(!environment(bodyPhotos: true, authentication: false).offersBodyPhotos)
    }

    @Test func bodyPhotosAreHiddenWithoutTheService() {
        #expect(!environment(bodyPhotos: false, authentication: true).offersBodyPhotos)
    }
}
