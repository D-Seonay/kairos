import ActivityKit
import Foundation

/// La Live Activity de la séance en cours (spec M4 §15.3). Elle ne porte que le titre, des dates, la série suivante prévue et le
/// compte des séries : aucune donnée de santé (spec M4 §15.4).
public struct PulseSessionAttributes: ActivityAttributes, Sendable {
    /// Ce qui change pendant la séance. Les comptes à rebours partent des dates, jamais d'un compteur mis à jour chaque seconde.
    public struct ContentState: Codable, Hashable, Sendable {
        public var title: String
        public var startedAt: Date
        public var restStartedAt: Date?
        public var restEndsAt: Date?
        /// « Développé couché à la barre · série 2 · 70 kg × 5 » ; `nil` après la dernière série.
        public var nextSet: String?
        /// La série que « Valider » coche, hors repos ; `nil` sans série à valider. Optionnel : une activité lancée par une version
        /// d'avant ce bouton se relit sans lui.
        public var nextSetID: UUID?
        /// Les séries de travail validées, échauffement exclu. Optionnel : une activité lancée par une version d'avant le compte
        /// des séries se relit sans lui.
        public var doneSets: Int?
        /// Les séries de travail prévues ; `nil` ou 0 sans série prévue, et la progression ne s'affiche pas.
        public var plannedSets: Int?

        public init(title: String, startedAt: Date, restStartedAt: Date? = nil, restEndsAt: Date? = nil, nextSet: String? = nil,
                    nextSetID: UUID? = nil, doneSets: Int? = nil, plannedSets: Int? = nil) {
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

    /// La séance de l'activité : au lancement, l'app ferme celles qui ne correspondent plus à la séance en cours.
    public var sessionID: UUID

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}
