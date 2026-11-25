#if DEBUG
import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SupplementsFeature
import SwiftUI

/// Les doublures des aperçus : un onglet Profil en mémoire, sur une horloge fixe (vendredi 20 novembre, midi), dix semaines de
/// musculation (lundi, mercredi, vendredi, charges qui montent) et une sortie de 10,6 km, un score ce matin, des pesées tous les
/// deux jours qui descendent doucement et une masse grasse par semaine. Sans historique : un nouvel utilisateur du jour.
@MainActor
enum ProfilePreviewSupport {
    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    nonisolated static let now: Date = {
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 11, day: 20, hour: 12)
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }()

    static let historyDays = 70

    static func environment(withHistory: Bool = true) async -> ProfileEnvironment {
        let clock: @Sendable () -> Date = { now }
        let library = ContentLibrary.bundled
        let profiles = InMemoryProfileRepository()
        let programs = InMemoryProgramRepository()
        let recoveries = InMemoryRecoveryRepository(calendar: calendar)
        let workouts = InMemoryWorkoutRepository()
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let measurements = InMemoryBodyMeasurementRepository()
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises, library: library,
                                     now: clock)
        let onboarded = withHistory ? day(-historyDays, hour: 9) : now
        try? await profiles.save(UserProfile(firstName: withHistory ? "Mathéo" : nil, onboardingCompletedAt: onboarded,
                                             createdAt: onboarded, updatedAt: onboarded))
        if withHistory {
            for session in sessions() { try? await workouts.save(session) }
            for measurement in weighIns() { try? await measurements.save(measurement) }
            let today = day(0, hour: 0)
            try? await recoveries.save(DailyRecovery(day: today, score: 78, category: .normal, isEstimated: false,
                                                     calibration: .ready, createdAt: today, updatedAt: today))
            _ = try? await records.recomputeAll()
        }
        let service = ProfileService(profiles: profiles, programs: programs, workouts: workouts, recoveries: recoveries,
                                     records: personalRecords, userExercises: userExercises, library: library, calendar: calendar,
                                     now: clock)
        // Deux semaines de réveils à 7 h : la section « Sommeil » montre « Selon mes nuits (07:00) » et un coucher conseillé.
        let wokeUp = withHistory ? (0..<14).map { day(-$0, hour: 7) } : []
        return ProfileEnvironment(
            profile: service, body: BodyService(measurements: measurements, profiles: profiles, calendar: calendar, now: clock),
            settings: SettingsService(profiles: profiles, now: clock) { _, _ in }, healthCache: InMemoryHealthSampleCache(),
            inspector: PreviewInspector(), exporter: PreviewExporter(), eraser: PreviewEraser(),
            notificationStatus: { .authorized }, requestNotificationAuthorization: { true }, refreshHealth: {},
            appVersion: "1.0.2 (14)", privacyPolicyURL: nil, calendar: calendar, now: clock,
            bodyPhotos: BodyPhotoService(store: InMemoryBodyPhotoStore(), measurements: measurements, calendar: calendar, now: clock),
            ownerAuthentication: PreviewOwnerAuthentication(),
            sleepPlan: { SleepPlan(profile: try? await profiles.load(), wokeUp: wokeUp, calendar: calendar) })
    }

    /// Le jour `offset` (0 = aujourd'hui, négatif = passé) à l'heure donnée.
    static func day(_ offset: Int, hour: Int) -> Date {
        let start = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(byAdding: .hour, value: hour, to: start) ?? start
    }

    private static func sessions() -> [WorkoutSession] {
        (1...historyDays).compactMap { back -> WorkoutSession? in
            let start = day(-back, hour: 18)
            let weekday = calendar.component(.weekday, from: start)
            if back == 24 {
                return WorkoutSession(startedAt: start, kind: .run, source: .appleHealth, status: .completed, title: "Course",
                                      overallRPE: 6, durationMinutes: 58, distanceMeters: 10_600, createdAt: start,
                                      updatedAt: start)
            }
            guard [2, 4, 6].contains(weekday) else { return nil }
            return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed, title: "Séance",
                                  overallRPE: 7, durationMinutes: 60, sets: sets(back: back, at: start), createdAt: start,
                                  updatedAt: start)
        }
    }

    /// Les quatre levés de base à chaque séance : la charge monte de 2,5 kg par semaine.
    private static func sets(back: Int, at start: Date) -> [WorkoutSet] {
        let progress = Double((historyDays - back) / 7) * 2.5
        var sets: [WorkoutSet] = []
        func lift(_ id: String, _ name: String, kg: Double) {
            sets.append(WorkoutSet(order: sets.count + 1, exercise: .content(id: id), exerciseName: name, setType: .working,
                                   actualWeightKg: kg, actualReps: 5,
                                   completedAt: start.addingTimeInterval(Double(sets.count + 1) * 240)))
        }
        lift("back-squat-barbell", "Squat barre", kg: 95 + progress)
        lift("bench-press-barbell", "Développé couché à la barre", kg: 70 + progress)
        lift("deadlift-barbell", "Soulevé de terre", kg: 115 + progress)
        lift("overhead-press-barbell", "Développé militaire à la barre", kg: 42 + progress / 2)
        return sets
    }

    /// Une pesée tous les deux jours, de 80 kg vers 78 kg ; une masse grasse le lundi.
    private static func weighIns() -> [BodyMeasurement] {
        stride(from: 60, through: 2, by: -2).map { back in
            let date = day(-back, hour: 7)
            let isMonday = calendar.component(.weekday, from: date) == 2
            return BodyMeasurement(date: date, weightKg: 78 + Double(back) / 30 + 0.3 * sin(Double(back)),
                                   bodyFatPercent: isMonday ? 17 + Double(back) / 40 : nil, source: .appleHealth,
                                   healthKitUUID: "preview-\(back)", createdAt: date, updatedAt: date)
        }
    }

    static func model(withHistory: Bool = true) async -> ProfileModel {
        ProfileModel(environment: await environment(withHistory: withHistory)) { _ in }
    }

    /// Deux compléments en mémoire.
    static func supplements() -> SupplementsModel {
        let created = day(-20, hour: 9)
        let creatine = Supplement(name: "Créatine", form: .powder, dose: 5, unit: .gram, timing: .fixedTime, timeOfDayMinutes: 480,
                                  days: .everyDay, stockDoses: 38, lowStockThreshold: 7, order: 0, createdAt: created,
                                  updatedAt: created)
        let vitamin = Supplement(name: "Vitamine D3", form: .capsule, dose: 1_000, unit: .iu, timing: .fixedTime,
                                 timeOfDayMinutes: 480, days: .everyDay, order: 1, createdAt: created, updatedAt: created)
        let service = SupplementService(supplements: InMemorySupplementRepository(supplements: [creatine, vitamin]),
                                        programs: InMemoryProgramRepository(), profiles: InMemoryProfileRepository(),
                                        workouts: InMemoryWorkoutRepository(), reminders: nil, health: nil, calendar: calendar,
                                        now: { now })
        return SupplementsModel(environment: SupplementsEnvironment(service: service,
                                                                    notifications: StubNotificationAuthorizer(granted: true),
                                                                    calendar: calendar, now: { now }))
    }

    static let screens = ProfileAppScreens(
        healthDiagnostics: { AnyView(Text(verbatim: "Diagnostic Apple Santé")) },
        dataDebug: { AnyView(Text(verbatim: "Données")) },
        eraseConfirmation: { _ in AnyView(Text(verbatim: "Confirmation de suppression")) })
}

private struct PreviewInspector: StoreInspector {
    func counts() async throws -> [StoreTable: Int] { [:] }
    func cloudAccountStatus() async -> CloudAccountStatus { .available }
}

private struct PreviewExporter: DataExporter {
    func exportJSON() async throws -> URL { URL(fileURLWithPath: NSTemporaryDirectory()) }
    func exportCSVArchive() async throws -> URL { URL(fileURLWithPath: NSTemporaryDirectory()) }
}

/// Face ID des aperçus : un code existe et l'authentification réussit toujours.
private struct PreviewOwnerAuthentication: DeviceOwnerAuthenticating {
    func isAvailable() async -> Bool { true }
    func authenticate(reason: String) async -> Bool { true }
}

private struct PreviewEraser: DataEraser {
    func eraseEverything(options: EraseOptions) async throws {}
}

/// Prépare le modèle de l'aperçu puis affiche l'onglet, qui lit son profil à son apparition.
struct ProfilePreviewHost: View {
    var withHistory = true
    @State private var model: ProfileModel?
    @State private var supplements = ProfilePreviewSupport.supplements()

    var body: some View {
        Group {
            if let model {
                ProfileScreen(model: model, supplements: supplements, screens: ProfilePreviewSupport.screens,
                              onOpenStats: {}, onOpenRecords: {}, onErased: {})
            } else {
                ProgressView()
            }
        }
        .task { model = await ProfilePreviewSupport.model(withHistory: withHistory) }
        .preferredColorScheme(.light)
    }
}

#Preview("Profil") {
    ProfilePreviewHost()
}

#Preview("Profil, très grand texte") {
    ProfilePreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Profil, nouvel utilisateur") {
    ProfilePreviewHost(withHistory: false)
}
#endif
