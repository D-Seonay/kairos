import PulseDomain

/// La suppression totale passée par la file du rafraîchisseur : elle attend la fin du passage en cours, pour qu'aucun
/// score ni instantané du widget ne soit réécrit après l'effacement.
public struct SerializedDataEraser: DataEraser {
    private let refresher: DayRefresher
    private let inner: any DataEraser

    public init(refresher: DayRefresher, inner: any DataEraser) {
        self.refresher = refresher
        self.inner = inner
    }

    public func eraseEverything(options: EraseOptions) async throws {
        try await refresher.eraseEverything(using: inner, options: options)
    }
}
