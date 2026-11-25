import Foundation
import PulseDomain

/// Ce que Siri et l'app Raccourcis répondent aux raccourcis de Pulse : le score du jour et son état, la prise d'un complément.
public enum ShortcutText {
    /// Le score enregistré pour le jour de `now` ; `nil` tant qu'il n'est pas calculé (avant 4 h, ou nuit pas encore lue).
    public static func todaysRecovery(_ recoveries: [DailyRecovery], now: Date, calendar: Calendar) -> DailyRecovery? {
        recoveries.filter { calendar.isDate($0.day, inSameDayAs: now) }.max { $0.updatedAt < $1.updatedAt }
    }

    /// « Ton score de récupération est de 72 sur 100 : forme optimale. » ; l'état est toujours dit, et un score estimé
    /// d'après le check-in le dit aussi. `calibration` est le marqueur parlé de l'accueil (« en calibration, 9 nuits »,
    /// `FactorFormatter.spokenMarker`) : dit après l'état quand l'accueil l'affiche, jamais pour un score estimé.
    public static func recoveryScore(_ recovery: DailyRecovery?, calibration: String? = nil) -> String {
        guard let recovery else {
            return String(localized: "Ton score de récupération n'est pas encore prêt. Ouvre Pulse pour le calculer.", bundle: .module)
        }
        let score = Int(recovery.score.rounded())
        let state = recovery.category.sentenceName
        if recovery.isEstimated {
            return String(localized: "Ton score de récupération est estimé à \(score) sur 100 : \(state).", bundle: .module)
        }
        if let calibration, !calibration.isEmpty {
            return String(localized: "Ton score de récupération est de \(score) sur 100 : \(state), \(calibration).", bundle: .module)
        }
        return String(localized: "Ton score de récupération est de \(score) sur 100 : \(state).", bundle: .module)
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
    /// compte des majuscules ni des accents. Un nom de deux lettres ou moins (« D », « B6 ») n'est cherché que dans ce sens-là :
    /// sinon presque toute phrase le contiendrait. Une recherche vide rend tout.
    public static func matching(_ query: String, in supplements: [Supplement]) -> [Supplement] {
        let needle = fold(query)
        guard !needle.isEmpty else { return supplements }
        return supplements.filter { supplement in
            let name = fold(supplement.name)
            guard !name.isEmpty else { return false }
            return name.contains(needle) || (name.count > 2 && needle.contains(name))
        }
    }

    /// Les compléments qu'un raccourci désigne par identifiant, archivés compris : un raccourci enregistré avant l'archivage se
    /// résout, et dit ensuite que le complément n'est plus dans Pulse.
    public static func entities(for identifiers: [UUID], in overview: SupplementOverview) -> [Supplement] {
        let wanted = Set(identifiers)
        return (overview.supplements + overview.archived).filter { wanted.contains($0.id) }
    }

    /// Avant la prise : `nil` quand le complément est encore dans la liste et peut être coché, `.unknown` s'il est archivé ou
    /// supprimé (rien n'est coché).
    public static func refusal(supplementID: UUID, in overview: SupplementOverview) -> Outcome? {
        overview.supplements.contains { $0.id == supplementID } ? nil : .unknown
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
