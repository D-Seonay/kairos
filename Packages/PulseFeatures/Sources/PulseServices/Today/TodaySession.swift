import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine

/// La séance du jour : celle du programme, ajustée au score, ou rétablie si l'utilisateur a gardé l'originale.
public struct TodaySession: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        case planned, adjusted, restored
    }

    public var plannedDay: PlannedDay
    public var adjusted: AdjustedSession?
    public var originalChosen: Bool
    /// Vrai pendant une semaine de décharge acceptée : le jour de musculation perd 40 % de ses séries (spec M6 §10).
    public var isDeload: Bool

    /// `recovery` est le score du jour : nul avant 4 h ou tant qu'aucun score n'existe. Pendant une décharge, le score ajuste
    /// le jour déjà allégé.
    public init(plannedDay: PlannedDay, recovery: DailyRecovery?, deload: Bool = false) {
        self.plannedDay = plannedDay
        isDeload = deload && plannedDay.routineDay?.kind == .strength
        let base = plannedDay.routineDay.map { deload ? DeloadAdjuster.apply($0).day : $0 }
        adjusted = recovery.flatMap { recovery in
            base.map { SessionAdjuster.adjust($0, category: recovery.category) }
        }
        originalChosen = recovery?.originalSessionChosen == true
    }

    /// Planifiée tant qu'aucun ajustement ne s'applique (pas de score, repos, ou score optimal) ; rétablie seulement s'il y en avait un.
    public var status: Status {
        guard let adjusted, !adjusted.adjustments.isEmpty else { return .planned }
        return originalChosen ? .restored : .adjusted
    }

    public var originalDay: RoutineDay? { plannedDay.routineDay }

    /// Le jour prévu, allégé pendant une décharge : ce que « Séance d'origine » démarre.
    public var baseDay: RoutineDay? {
        guard isDeload, let day = originalDay else { return originalDay }
        return DeloadAdjuster.apply(day).day
    }

    /// Le jour à faire : l'ajusté tant que l'ajustement tient, le jour prévu (allégé pendant une décharge) sinon.
    public var activeDay: RoutineDay? {
        status == .adjusted ? adjusted?.day : baseDay
    }

    /// Vrai si la séance est allégée : en décharge, ou ajustée avec au moins un ajustement autre que le repos conseillé.
    public var isLightened: Bool {
        if isDeload { return true }
        guard status == .adjusted, let adjusted else { return false }
        return adjusted.adjustments.contains { $0.kind != .rest }
    }

    public var title: String? {
        guard let day = originalDay else { return nil }
        switch day.kind {
        case .run:
            return day.runType?.localizedName ?? day.name
        case .strength:
            if isDeload { return String(localized: "\(day.name), décharge", bundle: .module) }
            guard status == .adjusted, adjusted?.isVolumeReduced == true else { return day.name }
            return String(localized: "\(day.name), volume allégé", bundle: .module)
        }
    }
}
