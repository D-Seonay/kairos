import Foundation
import Synchronization

/// Retient l'étape atteinte pour reprendre l'onboarding là où l'utilisateur l'a laissé.
public protocol OnboardingStepStore: Sendable {
    func load() -> OnboardingStep?
    func save(_ step: OnboardingStep)
    func clear()
}

/// Étape conservée dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
public struct UserDefaultsOnboardingStepStore: OnboardingStepStore {
    private let suiteName: String?
    private let key: String

    public init(suiteName: String?, key: String = "onboarding.step") {
        self.suiteName = suiteName
        self.key = key
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func load() -> OnboardingStep? {
        let defaults = defaults
        guard defaults.object(forKey: key) != nil else { return nil }
        return OnboardingStep(rawValue: defaults.integer(forKey: key))
    }

    public func save(_ step: OnboardingStep) {
        defaults.set(step.rawValue, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}

/// Étape conservée en mémoire, pour les tests et les aperçus.
public final class InMemoryOnboardingStepStore: OnboardingStepStore {
    private let stored = Mutex<OnboardingStep?>(nil)

    public init(_ step: OnboardingStep? = nil) {
        stored.withLock { $0 = step }
    }

    public func load() -> OnboardingStep? {
        stored.withLock { $0 }
    }

    public func save(_ step: OnboardingStep) {
        stored.withLock { $0 = step }
    }

    public func clear() {
        stored.withLock { $0 = nil }
    }
}
