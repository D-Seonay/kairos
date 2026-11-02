#if DEBUG
import Foundation
import PulseContent
import PulseDomain
import PulseServices
import SwiftUI

/// Les doublures des aperçus : un accueil en mémoire, sur un scénario Apple Santé et une horloge fixes (lundi 2 novembre).
@MainActor
enum TodayPreviewSupport {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static func date(day: Int, hour: Int) -> Date {
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 11, day: day, hour: hour)
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    /// La charge d'entraînement d'un aperçu : cachée (onboarding du jour), ou 40 jours d'historique et quatre séances par semaine,
    /// la dernière un peu plus longue pour donner le ratio voulu.
    enum Load {
        case hidden
        /// Ratio aigu / chronique de 1,12.
        case optimal
        /// Ratio aigu / chronique de 1,7.
        case risk

        /// La durée des séances de la dernière semaine, en minutes ; les trois semaines d'avant font quatre séances de 60 minutes.
        var acuteMinutes: Double {
            switch self {
            case .hidden: 60
            case .optimal: 70
            case .risk: 133
            }
        }
    }

    /// Quatre semaines de séances à RPE 7, finissant à `now`.
    private static func sessions(for load: Load, now: Date) -> [WorkoutSession] {
        (0..<4).flatMap { week in
            [0, 1, 3, 5].compactMap { offset -> WorkoutSession? in
                let day = calendar.date(byAdding: .day, value: -(week * 7 + offset), to: calendar.startOfDay(for: now))
                guard let start = day.flatMap({ calendar.date(byAdding: .hour, value: 18, to: $0) }) else { return nil }
                return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: .completed, title: "Séance",
                                      overallRPE: 7, durationMinutes: week == 0 ? load.acuteMinutes : 60,
                                      createdAt: start, updatedAt: start)
            }
        }
    }

    /// Un modèle prêt à rafraîchir : profil et programme `templateID` déjà enregistrés (`nil` : « Je construis le mien »),
    /// et `seeded` comme score du jour déjà enregistré (un score estimé reste tant que les nuits ne suffisent pas).
    static func model(scenario: HealthScenario, now: Date, templateID: String? = "ppl-3",
                      seeded: DailyRecovery? = nil, load: Load = .hidden) async -> TodayModel {
        let calendar = calendar
        let library = ContentLibrary.bundled
        let profiles = InMemoryProfileRepository()
        let programs = InMemoryProgramRepository()
        let recovery = InMemoryRecoveryRepository(calendar: calendar)
        let workouts = InMemoryWorkoutRepository()
        let onboarded = load == .hidden ? now : calendar.date(byAdding: .day, value: -40, to: now) ?? now
        for session in sessions(for: load, now: now) where load != .hidden {
            try? await workouts.save(session)
        }
        var profile = UserProfile(firstName: "Mathéo", onboardingCompletedAt: onboarded, createdAt: now, updatedAt: now)
        if let template = templateID.flatMap({ library.programTemplate(id: $0) }) {
            let program = ProgramAdopter(library: library).adopt(
                template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
            try? await programs.save(program)
            profile.activeProgramID = program.id
        }
        try? await profiles.save(profile)
        if let seeded {
            try? await recovery.save(seeded)
        }
        let source = ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar)
        let refresher = DayRefresher(
            profiles: profiles, programs: programs, recovery: recovery,
            nightHistory: NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar),
            scores: DailyScoreService(recovery: recovery, calendar: calendar),
            widgets: StubWidgetPublisher(), notifications: StubNotificationScheduler(), activity: InMemoryDayActivityLog(),
            calendar: calendar, now: { now })
        return TodayModel(environment: TodayEnvironment(
            refresher: refresher, workouts: workouts, userExercises: InMemoryUserExerciseRepository(), library: library,
            calendar: calendar, now: { now }))
    }

    /// Un score estimé de surmenage (check-in très bas), lundi 2 novembre.
    static var overreached: DailyRecovery {
        let now = date(day: 2, hour: 8)
        return DailyRecovery(day: calendar.startOfDay(for: now), score: 25, category: .overreached, isEstimated: true,
                             missingFactors: Factor.allCases, calibration: .calibrating(nights: 0), createdAt: now, updatedAt: now)
    }
}

/// Prépare le modèle de l'aperçu puis affiche l'accueil, qui se rafraîchit à son apparition.
struct TodayPreviewHost: View {
    let scenario: HealthScenario
    let now: Date
    var templateID: String? = "ppl-3"
    var seeded: DailyRecovery?
    var load: TodayPreviewSupport.Load = .hidden
    @State private var model: TodayModel?

    var body: some View {
        Group {
            if let model {
                TodayView(model: model, onOpenProfile: {})
            } else {
                ProgressView()
            }
        }
        .task {
            model = await TodayPreviewSupport.model(scenario: scenario, now: now, templateID: templateID, seeded: seeded, load: load)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Bonne nuit, lundi Push") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 2, hour: 8))
}

#Preview("Charge 1,12, zone optimale") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 2, hour: 8), load: .optimal)
}

#Preview("Charge 1,7, risque de blessure") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 2, hour: 8), load: .risk)
}

#Preview("Mauvaise nuit, Push allégé") {
    TodayPreviewHost(scenario: .badNight, now: TodayPreviewSupport.date(day: 2, hour: 8))
}

#Preview("Surmenage, mobilité ou repos") {
    TodayPreviewHost(scenario: .threeNights, now: TodayPreviewSupport.date(day: 2, hour: 8), seeded: TodayPreviewSupport.overreached)
}

#Preview("Repos sous 65") {
    TodayPreviewHost(scenario: .badNight, now: TodayPreviewSupport.date(day: 3, hour: 8))
}

#Preview("Fractionné en fatigue") {
    TodayPreviewHost(scenario: .badNight, now: TodayPreviewSupport.date(day: 5, hour: 8), templateID: "runner-strength")
}

#Preview("Sans VFC") {
    TodayPreviewHost(scenario: .missingHRV, now: TodayPreviewSupport.date(day: 2, hour: 8))
}

#Preview("Check-in (trois nuits)") {
    TodayPreviewHost(scenario: .threeNights, now: TodayPreviewSupport.date(day: 2, hour: 8))
}

#Preview("Jour de repos") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 3, hour: 8))
}

#Preview("Jour de course") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 2, hour: 8), templateID: "runner-strength")
}

#Preview("Sans programme") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 2, hour: 8), templateID: nil)
}

#Preview("Avant 4 h") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 2, hour: 3))
}
#endif
