#if DEBUG
import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Les doublures des aperçus : un onglet Stats en mémoire, sur une horloge fixe (vendredi 20 novembre, midi) et huit semaines
/// d'historique de synthèse (musculation poussée lundi, tirage mercredi et jambes vendredi avec des charges qui montent, course
/// le samedi, vélo un dimanche sur deux, nuits mesurées avec quelques trous et quelques matins estimés par check-in) et les
/// records qui en découlent. Sans historique : un nouvel utilisateur du jour.
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
            _ = try? await records.recomputeAll()
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
            case let weekday where [2, 4, 6].contains(weekday):
                return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed, title: "Séance",
                                      overallRPE: 7, tonnageKg: 7_500 + Double(back % 5) * 400,
                                      durationMinutes: lastWeek ? 70 : 60, sets: sets(weekday: weekday, back: back, at: start),
                                      createdAt: start, updatedAt: start)
            case 7:
                // Une sortie longue, trois semaines avant, pour un temps sur 10 km.
                let isLong = back / 7 == 3
                return WorkoutSession(startedAt: start, kind: .run, source: .appleHealth, status: .completed, title: "Course",
                                      overallRPE: 6, durationMinutes: isLong ? 58 : 45, distanceMeters: isLong ? 10_600 : 8_200,
                                      createdAt: start, updatedAt: start)
            case 1 where (back / 7).isMultiple(of: 2):
                return WorkoutSession(startedAt: start, kind: .ride, source: .appleHealth, status: .completed, title: "Vélo",
                                      overallRPE: 4, durationMinutes: 90, distanceMeters: 36_000, createdAt: start,
                                      updatedAt: start)
            default:
                return nil
            }
        }
    }

    /// Poussée le lundi, tirage le mercredi, jambes le vendredi : la charge monte de 2,5 kg par semaine, le tronc n'a pas de
    /// série à lui (il ressort comme peu sollicité) et le haut du corps l'emporte sur le bas.
    private static func sets(weekday: Int, back: Int, at start: Date) -> [WorkoutSet] {
        let progress = Double((historyDays - back) / 7) * 2.5
        var sets: [WorkoutSet] = []
        func lift(_ id: String, _ name: String, sets count: Int, reps: Int, kg: Double) {
            for _ in 0..<count {
                sets.append(WorkoutSet(order: sets.count + 1, exercise: .content(id: id), exerciseName: name, setType: .working,
                                       actualWeightKg: kg, actualReps: reps,
                                       completedAt: start.addingTimeInterval(Double(sets.count + 1) * 180)))
            }
        }
        switch weekday {
        case 2:
            lift("bench-press-barbell", "Développé couché à la barre", sets: 3, reps: 5, kg: 70 + progress)
            lift("overhead-press-barbell", "Développé militaire à la barre", sets: 3, reps: 6, kg: 40 + progress / 2)
            lift("triceps-pushdown-cable", "Extension triceps poulie haute", sets: 3, reps: 12, kg: 25)
        case 4:
            lift("barbell-row", "Rowing à la barre", sets: 3, reps: 8, kg: 60 + progress)
            lift("lat-pulldown-machine", "Tirage vertical machine convergente", sets: 3, reps: 10, kg: 55)
            lift("barbell-curl", "Curl à la barre", sets: 3, reps: 10, kg: 30)
        default:
            lift("back-squat-barbell", "Squat barre", sets: 3, reps: 5, kg: 90 + progress)
            lift("deadlift-barbell", "Soulevé de terre", sets: 1, reps: 5, kg: 110 + progress)
        }
        return sets
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

#Preview("Stats, Records") {
    StatsPreviewHost(view: .records)
}

#Preview("Stats, nouvel utilisateur") {
    StatsPreviewHost(withHistory: false)
}
#endif
