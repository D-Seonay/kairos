import Foundation
import PulseDomain

/// Ce que Siri et l'app Raccourcis répondent aux raccourcis de Pulse : le score du jour et son état, la prise d'un complément.
public enum ShortcutText {
    /// Le score enregistré pour le jour de `now` ; `nil` tant qu'il n'est pas calculé (avant 4 h, ou nuit pas encore lue).
    public static func todaysRecovery(_ recoveries: [DailyRecovery], now: Date, calendar: Calendar) -> DailyRecovery? {
        recoveries.filter { calendar.isDate($0.day, inSameDayAs: now) }.max { $0.updatedAt < $1.updatedAt }
    }

    /// « Ton score de récupération est de 72 sur 100 : forme optimale. » ; l'état est toujours dit, et un score estimé
    /// d'après le check-in le dit aussi.
    public static func recoveryScore(_ recovery: DailyRecovery?) -> String {
        guard let recovery else {
            return String(localized: "Ton score de récupération n'est pas encore prêt. Ouvre Pulse pour le calculer.", bundle: .module)
        }
        let score = Int(recovery.score.rounded())
        let state = recovery.category.sentenceName
        return recovery.isEstimated
            ? String(localized: "Ton score de récupération est estimé à \(score) sur 100 : \(state).", bundle: .module)
            : String(localized: "Ton score de récupération est de \(score) sur 100 : \(state).", bundle: .module)
    }

    /// La réponse après « J'ai pris ma créatine ».
    public static func supplement(_ outcome: SupplementShortcut.Outcome, name: String) -> String {
        switch outcome {
        case .taken: String(localized: "C'est noté : prise de \(name) cochée pour aujourd'hui.", bundle: .module)
        case .alreadyTaken: String(localized: "La prise de \(name) est déjà cochée aujourd'hui.", bundle: .module)
        case .unknown: String(localized: "Ce complément n'est plus dans Pulse.", bundle: .module)
        }
    }
}

/// Le choix du complément d'un raccourci « J'ai pris… » : l'ordre des propositions, la recherche par nom et le sens d'une prise
/// refusée.
public enum SupplementShortcut {
    public enum Outcome: Sendable, Equatable {
        case taken
        case alreadyTaken
        /// Le complément a été supprimé entre la question et la réponse.
        case unknown
    }

    /// Les compléments non archivés, proposés dans cet ordre : ceux du jour encore à prendre (par heure prévue), ceux du jour
    /// déjà pris, puis les autres (par ordre de la liste).
    public static func suggestions(_ overview: SupplementOverview) -> [Supplement] {
        let due = overview.items.sorted { lhs, rhs in
            if lhs.isTaken != rhs.isTaken { return !lhs.isTaken }
            if lhs.plannedMinutes != rhs.plannedMinutes { return lhs.plannedMinutes < rhs.plannedMinutes }
            return lhs.supplement.order < rhs.supplement.order
        }.map(\.supplement)
        let dueIDs = Set(due.map(\.id))
        let others = overview.supplements.filter { !dueIDs.contains($0.id) }.sorted { $0.order < $1.order }
        return due + others
    }

    /// Les compléments dont le nom contient la recherche, ou y est contenu (« ma créatine » trouve « Créatine »), sans tenir
    /// compte des majuscules ni des accents. Une recherche vide rend tout.
    public static func matching(_ query: String, in supplements: [Supplement]) -> [Supplement] {
        let needle = fold(query)
        guard !needle.isEmpty else { return supplements }
        return supplements.filter { supplement in
            let name = fold(supplement.name)
            return !name.isEmpty && (name.contains(needle) || needle.contains(name))
        }
    }

    /// `SupplementService.take` rend faux pour une prise déjà cochée comme pour un complément disparu : `known` les distingue.
    public static func outcome(recorded: Bool, supplementID: UUID, known: [Supplement]) -> Outcome {
        if recorded { return .taken }
        return known.contains { $0.id == supplementID } ? .alreadyTaken : .unknown
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
