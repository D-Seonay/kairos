import HealthKit

/// Réveille l'app quand Apple Santé reçoit une nouvelle nuit, VFC ou fréquence de repos, même app fermée.
/// `HKHealthStore` est thread-safe, d'où `@unchecked Sendable`.
public final class HealthKitBackgroundDelivery: @unchecked Sendable {
    private let store: HKHealthStore

    public init(reader: HealthKitReader) {
        store = reader.store
    }

    /// Lance une requête d'observation par type observé et active la livraison immédiate en arrière-plan.
    /// À chaque réveil, `onChange` est attendu, puis HealthKit est prévenu que la livraison est traitée, même après une erreur.
    public func start(onChange: @escaping @Sendable () async -> Void) {
        for type in HealthKitTypes.observed {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
                let done = CompletionBox(completion)
                Task {
                    await onChange()
                    done.call()
                }
            }
            store.execute(query)
            // Sans l'autorisation ou le droit d'arrière-plan, l'activation échoue : les lectures au premier plan restent.
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
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
