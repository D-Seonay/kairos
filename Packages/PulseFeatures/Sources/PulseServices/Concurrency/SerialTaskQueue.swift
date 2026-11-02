/// Une file d'opérations asynchrones : chacune démarre après la fin, réussie ou non, de la précédente, dans l'ordre des appels.
/// Les appels concurrents d'un service partagé (onboarding, accueil, livraison en arrière-plan) ne s'entrelacent plus
/// entre une lecture et l'écriture qui en dépend.
public actor SerialTaskQueue {
    /// La fin de la dernière opération confiée à la file ; la suivante l'attend.
    private var tail: Task<Void, Never>?

    public init() {}

    public func run<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task<T, any Error> {
            await previous?.value
            return try await operation()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}
