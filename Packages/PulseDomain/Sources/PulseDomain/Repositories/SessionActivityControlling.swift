import Foundation

/// Ce que la Live Activity de séance affiche. Ne contient que le titre, des durées, la prochaine série prévue et le compte des
/// séries de travail.
public struct SessionActivityState: Sendable, Equatable, Codable {
    public var sessionID: UUID
    public var title: String
    public var startedAt: Date
    public var restStartedAt: Date?
    public var restEndsAt: Date?
    public var nextSet: String?
    /// La série que le bouton « Valider » de l'activité coche : la série suivante, quand elle a ses valeurs. `nil` sans série à
    /// valider ou pour une valeur manquante, que seule l'app sait saisir.
    public var nextSetID: UUID?
    /// Les séries de travail validées, échauffement exclu, comme « Séries » en haut de l'écran de séance.
    public var doneSets: Int
    /// Les séries de travail prévues ; 0 pour une séance sans série, qui n'affiche pas de progression.
    public var plannedSets: Int

    public init(
        sessionID: UUID,
        title: String,
        startedAt: Date,
        restStartedAt: Date? = nil,
        restEndsAt: Date? = nil,
        nextSet: String? = nil,
        nextSetID: UUID? = nil,
        doneSets: Int = 0,
        plannedSets: Int = 0
    ) {
        self.sessionID = sessionID
        self.title = title
        self.startedAt = startedAt
        self.restStartedAt = restStartedAt
        self.restEndsAt = restEndsAt
        self.nextSet = nextSet
        self.nextSetID = nextSetID
        self.doneSets = doneSets
        self.plannedSets = plannedSets
    }
}

/// Pilote la Live Activity de la séance en cours. Implémenté par l'app au-dessus d'ActivityKit.
public protocol SessionActivityControlling: Sendable {
    /// Démarre la Live Activity de la séance.
    func start(_ state: SessionActivityState) async
    /// Met à jour la Live Activity en cours.
    func update(_ state: SessionActivityState) async
    /// Termine la Live Activity en cours.
    func end() async
    /// Termine toutes les Live Activities de séance, sauf celle de `sessionID` si elle est donnée.
    func endAll(except sessionID: UUID?) async
}

/// Doublure qui garde les états reçus (démarrage puis mises à jour), dans l'ordre, et compte les fins.
public actor StubSessionActivityController: SessionActivityControlling {
    public private(set) var states: [SessionActivityState] = []
    public private(set) var endCount = 0
    public private(set) var endAllCalls: [UUID?] = []

    public init() {}

    public func start(_ state: SessionActivityState) async {
        states.append(state)
    }

    public func update(_ state: SessionActivityState) async {
        states.append(state)
    }

    public func end() async {
        endCount += 1
    }

    public func endAll(except sessionID: UUID?) async {
        endAllCalls.append(sessionID)
    }
}
