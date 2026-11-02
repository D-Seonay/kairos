import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// Une ligne par ajustement du moteur, avec ce qu'il change en pratique ; ou la raison pour laquelle il n'y en a pas.
enum WhyChanges {
    typealias Change = WhyContent.Change

    static func make(recovery: DailyRecovery, session: TodaySession, library: ContentLibrary) -> [Change] {
        guard let original = session.originalDay else {
            return [Change(pill: "✓", title: String(localized: "Pas de séance aujourd'hui : rien à ajuster.", bundle: .module),
                           detail: nil)]
        }
        guard let adjusted = session.adjusted, !adjusted.adjustments.isEmpty else {
            return [Change(pill: "✓", title: String(localized: "Rien à alléger aujourd'hui.", bundle: .module), detail: nil)]
        }
        var changes = adjusted.adjustments.map { change(for: $0, adjusted: adjusted, original: original, library: library) }
        if keepsLoads(recovery.category, plannedDay: session.plannedDay) {
            changes.append(unchangedLoads)
        }
        return changes
    }

    private static func change(for adjustment: SessionAdjustment, adjusted: AdjustedSession, original: RoutineDay,
                               library: ContentLibrary) -> Change {
        let title = adjustment.reason
        switch adjustment.kind {
        case .volume:
            return Change(pill: "\u{2212}\(adjusted.removedSets)", title: title,
                          detail: lostSets(adjusted: adjusted, original: original, library: library))
        case .rpeCap:
            let cap = PulseFormat.decimal(adjustment.value ?? SessionAdjuster.fatigueRPECap, maxFractionDigits: 1)
            let detail = String(localized: "Arrête-toi deux répétitions avant l'échec sur chaque série de travail.", bundle: .module)
            return Change(pill: cap, title: title, detail: detail)
        case .rest:
            let extra = adjustment.value.map { "+" + PulseFormat.integer($0, unit: nil) } ?? "+"
            return Change(pill: extra, title: title, detail: longerRest(adjusted: adjusted, original: original, library: library))
        case .replaceWithMobility:
            let minutes = PulseFormat.integer(adjustment.value ?? Double(SessionAdjuster.mobilityMinutes), unit: nil)
            return Change(pill: minutes, title: title,
                          detail: String(localized: "La séance prévue reste disponible avec « Séance d'origine ».", bundle: .module))
        case .swapIntervalsForEasy:
            return Change(pill: "→", title: title, detail: nil)
        case .suggestRest:
            return Change(pill: "0", title: title, detail: nil)
        case .load, .deload:
            // Le moteur ne les produit pas encore : la raison seule est montrée.
            return Change(pill: "•", title: title, detail: nil)
        }
    }

    // MARK: - Détails

    /// « Une série en moins sur : A, B et C. » ; « Des séries en moins sur : … » si l'un des exercices en a perdu plusieurs.
    private static func lostSets(adjusted: AdjustedSession, original: RoutineDay, library: ContentLibrary) -> String? {
        let lost = original.exercises.sorted { $0.order < $1.order }.compactMap { exercise -> (name: String, sets: Int)? in
            guard let after = adjusted.day.exercises.first(where: { $0.id == exercise.id }), after.sets < exercise.sets else {
                return nil
            }
            return (SessionPlanLine.name(of: exercise.exercise, library: library), exercise.sets - after.sets)
        }
        guard !lost.isEmpty else { return nil }
        let names = WhyContent.list(lost.map(\.name))
        if lost.contains(where: { $0.sets > 1 }) {
            return String(localized: "Des séries en moins sur : \(names).", bundle: .module)
        }
        return String(localized: "Une série en moins sur : \(names).", bundle: .module)
    }

    /// « 2 min 45 au lieu de 2 min sur A. » : le premier exercice de la séance.
    private static func longerRest(adjusted: AdjustedSession, original: RoutineDay, library: ContentLibrary) -> String? {
        guard let first = adjusted.day.exercises.min(by: { $0.order < $1.order }),
              let before = original.exercises.first(where: { $0.id == first.id }) else { return nil }
        let new = PulseFormat.restDuration(seconds: first.restSeconds)
        let old = PulseFormat.restDuration(seconds: before.restSeconds)
        let name = SessionPlanLine.name(of: first.exercise, library: library)
        return String(localized: "\(new) au lieu de \(old) sur \(name).", bundle: .module)
    }

    // MARK: - Charges

    /// Un score normal ou en fatigue un jour de musculation garde les charges, sans surcharge progressive.
    private static func keepsLoads(_ category: RecoveryCategory, plannedDay: PlannedDay) -> Bool {
        guard case .strength = plannedDay else { return false }
        return category == .normal || category == .moderateFatigue
    }

    private static var unchangedLoads: Change {
        Change(pill: "=", title: String(localized: "Charges inchangées", bundle: .module),
               detail: String(localized: "Celles de ta dernière séance, sans surcharge progressive aujourd'hui.", bundle: .module))
    }
}
