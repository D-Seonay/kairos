#if DEBUG
import Foundation
import PulseContent
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Les doublures des aperçus : un onglet Planning en mémoire, le mercredi 18 novembre 2026 à midi. Push Pull Legs, une course le
/// jeudi, Push le vendredi ; le lundi est fait, le mardi manqué, et deux semaines de novembre sont réussies.
@MainActor
enum PlanningPreviewSupport {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static func date(day: Int, hour: Int = 0) -> Date {
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 11, day: day, hour: hour)
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    static let now = date(day: 18, hour: 12)

    /// L'environnement de l'onglet, rempli, et l'identifiant d'une course lue d'Apple Santé pour le détail d'une activité.
    struct Preview {
        let environment: PlanningEnvironment
        let runID: UUID
    }

    static func preview() async -> Preview {
        let library = ContentLibrary.bundled
        let profiles = InMemoryProfileRepository()
        let programs = InMemoryProgramRepository()
        let workouts = InMemoryWorkoutRepository()
        let now = now
        let clock: @Sendable () -> Date = { now }
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let settings = InMemoryExerciseSettingsRepository()
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises, library: library,
                                     now: clock)
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: clock)
        let activeSession = ActiveSessionService(
            store: InMemoryActiveSessionStore(), workouts: workouts, profiles: profiles, settings: settings,
            userExercises: userExercises, records: records, library: library, restNotifier: StubRestTimerNotifier(),
            activity: StubSessionActivityController(), calendar: calendar, now: clock)
        let train = TrainEnvironment(
            profiles: profiles, programs: programs, recovery: InMemoryRecoveryRepository(calendar: calendar), workouts: workouts,
            userExercises: userExercises, exerciseSettings: settings, personalRecords: personalRecords, records: records,
            importer: importer, library: library, activeSession: activeSession, calendar: calendar, now: clock)
        let service = PlanningService(profiles: profiles, programs: programs, workouts: workouts,
                                      scheduledDays: InMemoryScheduledDayRepository(), calendar: calendar, now: clock)

        let push = RoutineDay(order: 0, name: "Push", kind: .strength)
        let pull = RoutineDay(order: 1, name: "Pull", kind: .strength)
        let legs = RoutineDay(order: 2, name: "Legs", kind: .strength)
        let run = RoutineDay(order: 3, name: "Endurance", kind: .run, runType: .easy, runTargetMinutes: 45)
        let created = date(day: 1)
        let program = Program(
            name: "PPL + course", sessionsPerWeek: 5, weekLayout: [push.id, pull.id, legs.id, run.id, push.id, nil, nil],
            days: [push, pull, legs, run], createdAt: created, updatedAt: created)
        try? await programs.save(program)
        try? await profiles.save(UserProfile(
            firstName: "Mathéo", restWeekdays: [.sunday], onboardingCompletedAt: created, activeProgramID: program.id))

        // Deux semaines réussies (les 2 et 9 novembre), le lundi 16 fait.
        for monday in [2, 9] {
            for offset in [0, 1, 2, 4] { await log(workouts, day: monday + offset, kind: .strength, tonnage: 9_800) }
            await log(workouts, day: monday + 3, kind: .run, meters: 8_200, source: .appleHealth)
        }
        await log(workouts, day: 14, hour: 9, kind: .run, meters: 10_000, source: .appleHealth)
        await log(workouts, day: 16, kind: .strength, tonnage: 11_240)
        let runID = await log(workouts, day: 17, hour: 7, kind: .run, meters: 8_200, source: .appleHealth)
        return Preview(
            environment: PlanningEnvironment(service: service, train: train, calendar: calendar, now: clock), runID: runID)
    }

    @discardableResult
    private static func log(_ workouts: InMemoryWorkoutRepository, day: Int, hour: Int = 18, kind: SessionKind,
                            tonnage: Double = 0, meters: Double? = nil, source: SessionSource = .pulse) async -> UUID {
        let start = date(day: day, hour: hour)
        let session = WorkoutSession(
            startedAt: start, endedAt: start.addingTimeInterval(2_700), kind: kind, source: source, status: .completed,
            title: kind == .run ? "Course" : "Push", tonnageKg: tonnage, durationMinutes: 45, distanceMeters: meters,
            averageHeartRate: kind == .run ? 150 : nil, estimatedRPE: kind == .run ? 7 : nil, createdAt: start, updatedAt: start)
        try? await workouts.save(session)
        return session.id
    }
}

/// Prépare l'environnement de l'aperçu, puis affiche l'onglet Planning.
private struct PlanningPreviewHost: View {
    @State private var content: (model: PlanningModel, train: TrainModel)?

    var body: some View {
        Group {
            if let content {
                PlanningView(model: content.model, train: content.train, onStartSession: { _ in }, onResumeSession: {})
            } else {
                ProgressView()
            }
        }
        .task {
            let preview = await PlanningPreviewSupport.preview()
            content = (PlanningModel(environment: preview.environment), TrainModel(environment: preview.environment.train))
        }
        .preferredColorScheme(.light)
    }
}

/// Le mois et la série : le modèle du mois se construit sur la semaine déjà lue, comme depuis l'onglet.
private struct MonthPreviewHost: View {
    @State private var model: MonthModel?

    var body: some View {
        NavigationStack {
            if let model {
                MonthView(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            let preview = await PlanningPreviewSupport.preview()
            let planning = PlanningModel(environment: preview.environment)
            await planning.load()
            model = planning.monthModel()
        }
        .preferredColorScheme(.light)
    }
}

/// Le détail d'une course lue d'Apple Santé.
private struct ActivityPreviewHost: View {
    @State private var model: ActivityDetailModel?

    var body: some View {
        NavigationStack {
            if let model {
                ActivityDetailView(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            let preview = await PlanningPreviewSupport.preview()
            model = PlanningModel(environment: preview.environment).activityDetailModel(sessionID: preview.runID)
        }
        .preferredColorScheme(.light)
    }
}

#Preview("Planning") {
    PlanningPreviewHost()
}

#Preview("Planning, accessibilité XL") {
    PlanningPreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Mois et série") {
    MonthPreviewHost()
}

#Preview("Mois et série, accessibilité XL") {
    MonthPreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Détail d'une course") {
    ActivityPreviewHost()
}

#Preview("Détail d'une course, accessibilité XL") {
    ActivityPreviewHost()
        .dynamicTypeSize(.accessibility3)
}
#endif
