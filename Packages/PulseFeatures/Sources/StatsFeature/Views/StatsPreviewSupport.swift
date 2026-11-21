#if DEBUG
import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Les doublures des aperçus : un onglet Stats en mémoire, sur une horloge fixe (vendredi 20 novembre, midi) et huit semaines
/// d'historique de synthèse (musculation lundi, mercredi et vendredi, course le samedi, vélo un dimanche sur deux, nuits
/// mesurées avec quelques trous et quelques matins estimés par check-in). Sans historique : un nouvel utilisateur du jour.
@MainActor
enum StatsPreviewSupport {
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

    static let historyDays = 56

    static func environment(withHistory: Bool = true) async -> StatsEnvironment {
        let clock: @Sendable () -> Date = { now }
        let library = ContentLibrary.bundled
        let profiles = InMemoryProfileRepository()
        let programs = InMemoryProgramRepository()
        let recoveries = InMemoryRecoveryRepository(calendar: calendar)
        let workouts = InMemoryWorkoutRepository()
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let settings = InMemoryExerciseSettingsRepository()
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises, library: library,
                                     now: clock)
        let onboarded = withHistory ? day(-historyDays, hour: 9) : now
        try? await profiles.save(UserProfile(firstName: "Mathéo", onboardingCompletedAt: onboarded, createdAt: onboarded,
                                             updatedAt: onboarded))
        if withHistory {
            for session in sessions() { try? await workouts.save(session) }
            for night in nights() { try? await recoveries.save(night) }
        }
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: clock)
        let activeSession = ActiveSessionService(
            store: InMemoryActiveSessionStore(), workouts: workouts, profiles: profiles, settings: settings,
            userExercises: userExercises, records: records, library: library, restNotifier: StubRestTimerNotifier(),
            activity: StubSessionActivityController(), calendar: calendar, now: clock)
        let train = TrainEnvironment(
            profiles: profiles, programs: programs, recovery: recoveries, workouts: workouts, userExercises: userExercises,
            exerciseSettings: settings, personalRecords: personalRecords, records: records, importer: importer, library: library,
            activeSession: activeSession, calendar: calendar, now: clock)
        let service = StatsService(profiles: profiles, programs: programs, workouts: workouts, recoveries: recoveries,
                                   records: personalRecords, userExercises: userExercises, library: library, calendar: calendar,
                                   now: clock)
        return StatsEnvironment(service: service, train: train, calendar: calendar, now: clock)
    }

    /// Le jour `offset` (0 = aujourd'hui, négatif = passé) à l'heure donnée.
    static func day(_ offset: Int, hour: Int) -> Date {
        let start = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(byAdding: .hour, value: hour, to: start) ?? start
    }

    /// La dernière semaine est un peu plus chargée que les autres, pour un ratio un peu au-dessus de 1.
    private static func sessions() -> [WorkoutSession] {
        (1...historyDays).compactMap { back -> WorkoutSession? in
            let start = day(-back, hour: 18)
            let lastWeek = back <= 7
            switch calendar.component(.weekday, from: start) {
            case 2, 4, 6:
                return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed, title: "Séance",
                                      overallRPE: 7, tonnageKg: 7_500 + Double(back % 5) * 400,
                                      durationMinutes: lastWeek ? 70 : 60, createdAt: start, updatedAt: start)
            case 7:
                return WorkoutSession(startedAt: start, kind: .run, source: .appleHealth, status: .completed, title: "Course",
                                      overallRPE: 6, durationMinutes: 45, distanceMeters: 8_200, createdAt: start, updatedAt: start)
            case 1 where (back / 7).isMultiple(of: 2):
                return WorkoutSession(startedAt: start, kind: .ride, source: .appleHealth, status: .completed, title: "Vélo",
                                      overallRPE: 4, durationMinutes: 90, distanceMeters: 36_000, createdAt: start,
                                      updatedAt: start)
            default:
                return nil
            }
        }
    }

    /// Des nuits ondulées autour de leur ligne de base ; une nuit sur neuf manque, un matin sur treize est estimé.
    private static func nights() -> [DailyRecovery] {
        (0..<historyDays).compactMap { back -> DailyRecovery? in
            guard back % 9 != 4 else { return nil }
            let date = day(-back, hour: 0)
            let wave = Double(back)
            let score = 72 + 14 * sin(wave * 0.7)
            let category: RecoveryCategory = score >= 84 ? .optimal
                : score >= 66 ? .normal
                : score >= 60 ? .moderateFatigue : .overreached
            guard back % 13 != 6 else {
                return DailyRecovery(day: date, score: 62, category: .moderateFatigue, isEstimated: true,
                                     missingFactors: Factor.allCases, calibration: .ready, createdAt: date, updatedAt: date)
            }
            return DailyRecovery(
                day: date, score: score, category: category, isEstimated: false, sdnnMs: 54 + 9 * sin(wave * 0.7),
                sdnnBaselineMs: 54 + wave * 0.04, restingHeartRate: 49 + 3 * cos(wave * 0.5), restingHeartRateBaseline: 49,
                asleepMinutes: Int(430 + 45 * sin(wave * 1.3)), deepMinutes: Int(82 + 12 * cos(wave)), calibration: .ready,
                createdAt: date, updatedAt: date)
        }
    }

    static func model(withHistory: Bool = true, view: StatsView = .load) async -> StatsModel {
        let model = StatsModel(environment: await environment(withHistory: withHistory))
        model.view = view
        return model
    }

    static func snapshot(period: StatsPeriod, withHistory: Bool = true) async -> StatsSnapshot? {
        try? await environment(withHistory: withHistory).service.snapshot(for: period)
    }
}

/// Prépare le modèle de l'aperçu puis affiche l'onglet, qui lit ses statistiques à son apparition.
struct StatsPreviewHost: View {
    var withHistory = true
    var view: StatsView = .load
    @State private var model: StatsModel?

    var body: some View {
        Group {
            if let model {
                StatsScreen(model: model)
            } else {
                ProgressView()
            }
        }
        .task { model = await StatsPreviewSupport.model(withHistory: withHistory, view: view) }
        .preferredColorScheme(.light)
    }
}

/// Calcule la lecture d'une période puis affiche une section seule, sur le fond de l'onglet.
struct StatsSectionPreview<Content: View>: View {
    var period: StatsPeriod = .month
    var withHistory = true
    @ViewBuilder let content: (StatsSnapshot, StatsWindow) -> Content
    @State private var snapshot: StatsSnapshot?

    var body: some View {
        ScrollView {
            if let snapshot {
                content(snapshot, StatsWindow(period: period, now: StatsPreviewSupport.now, calendar: StatsPreviewSupport.calendar))
                    .padding(PulseMetrics.spacing)
            } else {
                ProgressView()
            }
        }
        .background(PulsePalette.background)
        .task { snapshot = await StatsPreviewSupport.snapshot(period: period, withHistory: withHistory) }
        .preferredColorScheme(.light)
    }
}

#Preview("Stats, Charge") {
    StatsPreviewHost()
}

#Preview("Stats, Biométrie") {
    StatsPreviewHost(view: .biometry)
}

#Preview("Stats, nouvel utilisateur") {
    StatsPreviewHost(withHistory: false)
}
#endif
