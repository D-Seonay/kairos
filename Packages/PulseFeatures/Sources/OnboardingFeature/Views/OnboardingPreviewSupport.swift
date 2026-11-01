#if DEBUG
import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Les doublures des aperçus : un parcours en mémoire, à l'étape demandée, sur un scénario Apple Santé et une horloge fixes.
@MainActor
enum OnboardingPreviewSupport {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static let now: Date = {
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 11, day: 2, hour: 8)
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }()

    /// Le modèle d'un parcours qui reprend à `step` (le magasin d'étape le retient, `start()` le restaure).
    static func model(step: OnboardingStep, scenario: HealthScenario = .goodNight) -> OnboardingModel {
        let now = now
        let calendar = calendar
        let source = ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar)
        let environment = OnboardingEnvironment(
            profiles: InMemoryProfileRepository(), programs: InMemoryProgramRepository(), health: source,
            nightHistory: NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar),
            scores: DailyScoreService(recovery: InMemoryRecoveryRepository(calendar: calendar), calendar: calendar),
            notifications: StubNotificationAuthorizer(granted: true), library: .bundled,
            stepStore: InMemoryOnboardingStepStore(step), calendar: calendar, now: { now })
        return OnboardingModel(environment: environment)
    }
}
#endif
