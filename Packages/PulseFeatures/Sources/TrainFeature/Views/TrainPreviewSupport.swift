#if DEBUG
import Foundation
import PulseContent
import PulseDomain
import PulseServices
import SwiftUI

/// Les doublures des aperçus : un onglet « Séance » en mémoire, sur une horloge fixe (novembre 2026).
@MainActor
enum TrainPreviewSupport {
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

    /// Un modèle prêt à rafraîchir : profil et programme `templateID` déjà enregistrés (`nil` : sans programme),
    /// et un score du jour de catégorie `category` s'il y en a une.
    static func model(now: Date, templateID: String? = "ppl-3", category: RecoveryCategory? = nil) async -> TrainModel {
        let library = ContentLibrary.bundled
        let profiles = InMemoryProfileRepository()
        let programs = InMemoryProgramRepository()
        let recovery = InMemoryRecoveryRepository(calendar: calendar)
        var profile = UserProfile(firstName: "Mathéo", onboardingCompletedAt: now, createdAt: now, updatedAt: now)
        if let template = templateID.flatMap({ library.programTemplate(id: $0) }) {
            let program = ProgramAdopter(library: library).adopt(
                template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
            try? await programs.save(program)
            profile.activeProgramID = program.id
        }
        try? await profiles.save(profile)
        if let category {
            try? await recovery.save(DailyRecovery(day: calendar.startOfDay(for: now), score: 60, category: category,
                                                   isEstimated: false, calibration: .ready, createdAt: now, updatedAt: now))
        }
        return TrainModel(environment: environment(profiles: profiles, programs: programs, recovery: recovery, now: now))
    }

    private static func environment(profiles: any ProfileRepository, programs: any ProgramRepository,
                                    recovery: any RecoveryRepository, now: Date) -> TrainEnvironment {
        let library = ContentLibrary.bundled
        let workouts = InMemoryWorkoutRepository()
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let clock: @Sendable () -> Date = { now }
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises,
                                     library: library, now: clock)
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: clock)
        return TrainEnvironment(
            profiles: profiles, programs: programs, recovery: recovery, workouts: workouts, userExercises: userExercises,
            exerciseSettings: InMemoryExerciseSettingsRepository(), personalRecords: personalRecords, records: records,
            importer: importer, library: library, calendar: calendar, now: clock)
    }
}

/// Prépare le modèle de l'aperçu puis affiche l'onglet, qui se rafraîchit à son apparition.
struct TrainPreviewHost: View {
    let now: Date
    var templateID: String? = "ppl-3"
    var category: RecoveryCategory?
    @State private var model: TrainModel?

    var body: some View {
        Group {
            if let model {
                TrainView(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            model = await TrainPreviewSupport.model(now: now, templateID: templateID, category: category)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Lundi Push, ajustée") {
    TrainPreviewHost(now: TrainPreviewSupport.date(day: 2, hour: 9), category: .moderateFatigue)
}

#Preview("Lundi Push, sans score") {
    TrainPreviewHost(now: TrainPreviewSupport.date(day: 2, hour: 9))
}

#Preview("Jour de repos") {
    TrainPreviewHost(now: TrainPreviewSupport.date(day: 3, hour: 9))
}

#Preview("Course et musculation") {
    TrainPreviewHost(now: TrainPreviewSupport.date(day: 2, hour: 9), templateID: "runner-strength")
}

#Preview("Sans programme") {
    TrainPreviewHost(now: TrainPreviewSupport.date(day: 2, hour: 9), templateID: nil)
}
#endif
