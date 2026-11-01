public enum CloudAccountStatus: String, Sendable, Equatable {
    case available
    case noAccount
    case restricted
    case unknown
}

/// État du magasin pour l'écran de debug (spec M2 §8).
public protocol StoreInspector: Sendable {
    /// Enregistrements non supprimés par table.
    func counts() async throws -> [StoreTable: Int]
    func cloudAccountStatus() async -> CloudAccountStatus
}
