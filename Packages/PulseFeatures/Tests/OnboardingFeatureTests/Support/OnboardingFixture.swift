// swiftlint:disable force_unwrapping
import Foundation
import OnboardingFeature
import PulseContent
import PulseDomain
import PulseServices

/// Calendrier grégorien Europe/Paris en français et dates locales de Paris.
enum OnboardingClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static let now: Date = date("2026-11-02T08:00")

    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)!
    }
}

/// Les doublures d'un parcours d'onboarding, et le modèle construit dessus.
@MainActor
struct OnboardingFixture {
    let profiles = InMemoryProfileRepository()
    let programs = InMemoryProgramRepository()
    let recovery = InMemoryRecoveryRepository(calendar: OnboardingClock.calendar)
    let notifications: StubNotificationAuthorizer
    let stepStore = InMemoryOnboardingStepStore()
    let environment: OnboardingEnvironment

    init(scenario: HealthScenario = .goodNight, notificationsGranted: Bool = true, health: (any HealthSampleSource)? = nil) {
        let calendar = OnboardingClock.calendar
        let now = OnboardingClock.now
        let source = health ?? ScenarioHealthSource(scenario: scenario, now: now, calendar: calendar)
        let notifications = StubNotificationAuthorizer(granted: notificationsGranted)
        self.notifications = notifications
        environment = OnboardingEnvironment(
            profiles: profiles, programs: programs, health: source,
            nightHistory: NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar),
            scores: DailyScoreService(recovery: recovery, calendar: calendar), notifications: notifications,
            library: .bundled, stepStore: stepStore, calendar: calendar, now: { OnboardingClock.now })
    }

    func makeModel() -> OnboardingModel {
        OnboardingModel(environment: environment)
    }

    /// Un profil terminé, plus ancien que n'importe quel brouillon.
    static func completedProfile(firstName: String = "Camille") -> UserProfile {
        UserProfile(firstName: firstName, onboardingCompletedAt: OnboardingClock.date("2026-10-01T09:00"),
                    createdAt: OnboardingClock.date("2026-10-01T08:00"))
    }
}

extension OnboardingFixture {
    /// Mène le parcours jusqu'à l'adoption du programme recommandé.
    static func adoptRecommended(_ model: OnboardingModel) async {
        await model.start()
        await model.begin()
        await model.allowHealth()
        await model.continueFromProfile()
        await model.continueFromGoals()
        await model.adoptProgram()
    }
}
// swiftlint:enable force_unwrapping
