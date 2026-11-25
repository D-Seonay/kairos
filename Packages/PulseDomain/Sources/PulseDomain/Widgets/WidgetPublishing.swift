/// Publie l'instantané du jour pour le widget et l'écran verrouillé. Implémenté par l'app au-dessus du groupe d'apps partagé.
public protocol WidgetPublishing: Sendable {
    /// Remplace l'instantané publié et demande au widget de se recharger.
    func publish(_ snapshot: WidgetSnapshot) async
    /// Partage l'ambiance choisie (Ivoire ou Acier) avec les widgets, et les recharge si elle a changé.
    func publishTheme(_ theme: Theme) async
    /// Efface l'instantané et l'ambiance partagée (suppression totale des données).
    func clear() async
}

/// Doublure qui garde les instantanés et les ambiances publiés, dans l'ordre, et compte les effacements.
public actor StubWidgetPublisher: WidgetPublishing {
    public private(set) var published: [WidgetSnapshot] = []
    public private(set) var publishedThemes: [Theme] = []
    public private(set) var clearCount = 0

    public init() {}

    public func publish(_ snapshot: WidgetSnapshot) async {
        published.append(snapshot)
    }

    public func publishTheme(_ theme: Theme) async {
        publishedThemes.append(theme)
    }

    public func clear() async {
        clearCount += 1
    }
}
