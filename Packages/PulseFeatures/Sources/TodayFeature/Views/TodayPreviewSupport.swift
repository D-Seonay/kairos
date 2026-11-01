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

    /// Un modèle prêt à rafraîchir : profil et programme `templateID` déjà enregistrés (`nil` : « Je construis le mien »).
    static func model(scenario: HealthScenario, now: Date, templateID: String? = "ppl-3") async -> TodayModel {
        let calendar = calendar
        let library = ContentLibrary.bundled
        let profiles = InMemoryProfileRepository()
        let programs = InMemoryProgramRepository()
        var profile = UserProfile(firstName: "Mathéo", onboardingCompletedAt: now, createdAt: now, updatedAt: now)
        if let template = templateID.flatMap({ library.programTemplate(id: $0) }) {
            let program = ProgramAdopter(library: library).adopt(
                template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
            try? await programs.save(program)
            profile.activeProgramID = program.id
        }
        try? await profiles.save(profile)
        let source = ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar)
        let environment = TodayEnvironment(
            profiles: profiles, programs: programs,
            nightHistory: NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar),
            scores: DailyScoreService(recovery: InMemoryRecoveryRepository(calendar: calendar), calendar: calendar),
            library: library, calendar: calendar, now: { now })
        return TodayModel(environment: environment)
    }
}

/// Prépare le modèle de l'aperçu puis affiche l'accueil, qui se rafraîchit à son apparition.
struct TodayPreviewHost: View {
    let scenario: HealthScenario
    let now: Date
    var templateID: String? = "ppl-3"
    @State private var model: TodayModel?

    var body: some View {
        Group {
            if let model {
                TodayView(model: model, onOpenProfile: {})
            } else {
                ProgressView()
            }
        }
        .task { model = await TodayPreviewSupport.model(scenario: scenario, now: now, templateID: templateID) }
        .preferredColorScheme(.dark)
    }
}

#Preview("Bonne nuit, lundi Push") {
    TodayPreviewHost(scenario: .goodNight, now: TodayPreviewSupport.date(day: 2, hour: 8))
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
