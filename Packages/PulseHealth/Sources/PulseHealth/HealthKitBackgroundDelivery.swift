import Foundation
import HealthKit

/// Réveille l'app quand Apple Santé reçoit une nouvelle nuit, VFC ou fréquence de repos, même app fermée.
/// `HKHealthStore` est thread-safe ; l'état propre (requêtes en cours, action au réveil) est protégé par un verrou,
/// d'où `@unchecked Sendable`.
public final class HealthKitBackgroundDelivery: @unchecked Sendable {
    private let store: HKHealthStore
    private let lock = NSLock()
    private var queries: [HKObserverQuery] = []
    private var onChange: (@Sendable () async -> Void)?
    /// Une requête a reçu une erreur (accès pas encore accordé) : HealthKit l'a arrêtée.
    private var hasFailed = false

    public init(reader: HealthKitReader) {
        store = reader.store
    }

    /// Lance une requête d'observation par type observé et active la livraison immédiate en arrière-plan.
    /// À chaque réveil, `onChange` est attendu, puis HealthKit est prévenu que la livraison est traitée.
    public func start(onChange: @escaping @Sendable () async -> Void) {
        lock.withLock {
            self.onChange = onChange
            register()
        }
    }

    /// À rappeler une fois l'accès à Apple Santé accordé : sur une installation neuve, les requêtes lancées au démarrage,
    /// avant l'autorisation, ont échoué et HealthKit les a arrêtées. Sans effet si `start` n'a pas été appelé.
    public func restart() {
        lock.withLock { register() }
    }

    /// Au retour au premier plan : relance les requêtes si HealthKit en a arrêté une, par exemple parce que l'accès à Apple
    /// Santé a été accordé plus tard dans Réglages (spec M4 §20). Sans effet sinon : chaque relance provoque une lecture.
    public func restartIfStopped() {
        lock.withLock {
            guard hasFailed else { return }
            register()
        }
    }

    /// Remplace les requêtes en cours. Appelé sous le verrou.
    private func register() {
        guard let onChange else { return }
        hasFailed = false
        queries.forEach(store.stop)
        queries = HealthKitTypes.observed.map { type in
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                let done = CompletionBox(completion)
                // Une erreur (autorisation pas encore donnée, données protégées) ne porte aucune nouveauté à lire.
                guard error == nil else {
                    self?.markFailed()
                    done.call()
                    return
                }
                Task {
                    await onChange()
                    done.call()
                }
            }
            store.execute(query)
            // Sans l'autorisation ou le droit d'arrière-plan, l'activation échoue : les lectures au premier plan restent.
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
            return query
        }
    }
}

extension HealthKitBackgroundDelivery {
    fileprivate func markFailed() {
        lock.withLock { hasFailed = true }
    }
}

/// Le gestionnaire de fin de HealthKit n'est pas `Sendable` ; il est appelé une seule fois, après `onChange`.
private final class CompletionBox: @unchecked Sendable {
    private let completion: HKObserverQueryCompletionHandler

    init(_ completion: @escaping HKObserverQueryCompletionHandler) {
        self.completion = completion
    }

    func call() {
        completion()
    }
}
