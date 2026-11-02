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

    /// `recovery` est le score du jour : nul avant 4 h ou tant qu'aucun score n'existe.
    public init(plannedDay: PlannedDay, recovery: DailyRecovery?) {
        self.plannedDay = plannedDay
        adjusted = recovery.flatMap { recovery in
            plannedDay.routineDay.map { SessionAdjuster.adjust($0, category: recovery.category) }
        }
        originalChosen = recovery?.originalSessionChosen == true
    }

    public var status: Status {
        guard adjusted != nil else { return .planned }
        return originalChosen ? .restored : .adjusted
    }

    public var originalDay: RoutineDay? { plannedDay.routineDay }

    /// Le jour à faire : l'ajusté tant que l'ajustement tient, l'original sinon.
    public var activeDay: RoutineDay? {
        status == .adjusted ? adjusted?.day : originalDay
    }

    /// Vrai si la séance est allégée : ajustée avec au moins un ajustement autre que le repos conseillé.
    public var isLightened: Bool {
        guard status == .adjusted, let adjusted else { return false }
        return adjusted.adjustments.contains { $0.kind != .rest }
    }

    public var title: String? {
        guard let day = originalDay else { return nil }
        switch day.kind {
        case .run:
            return day.runType?.localizedName ?? day.name
        case .strength:
            guard status == .adjusted, adjusted?.isVolumeReduced == true else { return day.name }
            return String(localized: "\(day.name), volume allégé", bundle: .module)
        }
    }
}
