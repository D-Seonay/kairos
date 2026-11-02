/// Publie l'instantané du jour pour le widget et l'écran verrouillé. Implémenté par l'app au-dessus du groupe d'apps partagé.
public protocol WidgetPublishing: Sendable {
    /// Remplace l'instantané publié et demande au widget de se recharger.
    func publish(_ snapshot: WidgetSnapshot) async
    /// Efface l'instantané (suppression totale des données).
    func clear() async
}

/// Doublure qui garde les instantanés publiés, dans l'ordre, et compte les effacements.
public actor StubWidgetPublisher: WidgetPublishing {
    public private(set) var published: [WidgetSnapshot] = []
    public private(set) var clearCount = 0

    public init() {}

    public func publish(_ snapshot: WidgetSnapshot) async {
        published.append(snapshot)
    }

    public func clear() async {
        clearCount += 1
    }
}
