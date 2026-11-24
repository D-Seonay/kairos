import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// La carte d'une séance de musculation : titre, badge, résumé du jour à faire et boutons.
struct StrengthCard: Equatable {
    enum Badge: Equatable {
        case adjusted, planned
        /// Une semaine de décharge acceptée allège la séance (spec M6 §10).
        case deload
    }

    var title: String
    var badge: Badge
    var summary: SessionSummary
    /// « Pourquoi ? » n'a de sens que si un ajustement existe, gardé ou quitté.
    var showsWhy: Bool
    /// « Rétablir la séance d'origine » ou « Revenir à l'ajustée », comme sur l'écran « Pourquoi » ; nul sans ajustement.
    var originButton: String?
    var startButton: String
}

/// La carte d'une course : type, cible et, sous un score bas, la consigne du jour. « Démarrer la course » lance `launch`, la
/// course telle que la carte la montre (fractionné échangé contre une sortie facile sous une fatigue modérée).
struct RunCard: Equatable {
    var title: String
    var target: String?
    var suggestion: String?
    var launch: RunLaunch
    /// Une course est déjà terminée aujourd'hui : ni consigne ni « Démarrer la course ».
    var isDone = false
}

/// Ce que la carte « Séance du jour » montre, d'après la séance du jour et le score.
enum SessionCardState: Equatable {
    case strength(StrengthCard)
    /// Surmenage un jour de musculation : 20 min de mobilité ou repos complet, au choix ; la séance prévue reste disponible.
    case mobilityOrRest(dayName: String)
    case run(RunCard)
    /// `suggestsMobility` : le score du jour est sous 65, la carte propose 20 min de mobilité.
    case rest(next: NextSession?, suggestsMobility: Bool)
    case noProgram
    /// La séance de musculation du jour est terminée : son bilan remplace « Démarrer ».
    case done(DoneCard)
    /// Une séance est en cours : la carte propose de la reprendre.
    case inProgress(title: String)

    static let mobilityThreshold = 65.0

    /// Une séance en cours prime sur tout le reste. Le bilan de la séance faite ne remplace que la carte de musculation : un jour de
    /// repos, de course ou de mobilité garde la sienne. Une course faite aujourd'hui (`runDone`) retire le départ de la carte de
    /// course. `programID` est le programme actif, que la course lancée rappelle.
    static func make(session: TodaySession, score: TodayScore?, directory: ExerciseDirectory, done: DoneCard? = nil,
                     runDone: Bool = false, inProgressTitle: String? = nil, programID: UUID? = nil) -> SessionCardState {
        if let inProgressTitle {
            return .inProgress(title: inProgressTitle)
        }
        let state = planned(session: session, score: score, directory: directory, programID: programID)
        if case .strength = state, let done {
            return .done(done)
        }
        if case .run(var card) = state, runDone {
            card.isDone = true
            card.suggestion = nil
            return .run(card)
        }
        return state
    }

    /// Sans score du jour (avant 4 h, check-in à faire), la séance reste planifiée : aucun ajustement n'est proposé,
    /// et « Séance d'origine » serait refusée faute de score à modifier.
    private static func planned(session: TodaySession, score: TodayScore?, directory: ExerciseDirectory,
                                programID: UUID?) -> SessionCardState {
        let today: DailyRecovery? = if case .scored(let recovery)? = score { recovery } else { nil }
        let status = today == nil ? .planned : session.status
        switch session.plannedDay {
        case .noProgram:
            return .noProgram
        case .rest(let next):
            // Le score brut, pas l'arrondi : 64,6 s'affiche « 65 » mais reste une fatigue modérée.
            let suggestsMobility = today.map { $0.score < mobilityThreshold } ?? false
            return .rest(next: next, suggestsMobility: suggestsMobility)
        case .run(let day):
            let suggestion = status == .adjusted ? session.adjusted.flatMap(runSuggestion) : nil
            // L'ajustement ne part avec la course que tant qu'il tient : « Séance d'origine » rétablie, la course reste telle que prévue.
            let launch = RunLaunch.planned(day, programID: programID, adjusted: status == .adjusted ? session.adjusted : nil)
            return .run(RunCard(title: day.runType?.localizedName ?? day.name, target: runTarget(day), suggestion: suggestion,
                                launch: launch))
        case .strength(let day):
            return strength(day, session: session, status: status, directory: directory)
        }
    }

    private static func strength(_ day: RoutineDay, session: TodaySession, status: TodaySession.Status,
                                 directory: ExerciseDirectory) -> SessionCardState {
        switch status {
        case .adjusted:
            guard let adjusted = session.adjusted, !adjusted.isReplacedByMobility else {
                return .mobilityOrRest(dayName: day.name)
            }
            return .strength(StrengthCard(
                title: session.title ?? day.name, badge: .adjusted, summary: SessionSummary.make(day: adjusted.day, directory: directory),
                showsWhy: true, originButton: String(localized: "Rétablir la séance d'origine", bundle: .module),
                startButton: String(localized: "Démarrer la séance", bundle: .module)))
        case .restored:
            let base = session.baseDay ?? day
            return .strength(StrengthCard(
                title: session.isDeload ? session.title ?? day.name : day.name, badge: session.isDeload ? .deload : .planned,
                summary: SessionSummary.make(day: base, directory: directory),
                showsWhy: true, originButton: String(localized: "Revenir à l'ajustée", bundle: .module),
                startButton: String(localized: "Démarrer quand même", bundle: .module)))
        case .planned:
            let base = session.baseDay ?? day
            return .strength(StrengthCard(
                title: session.isDeload ? session.title ?? day.name : day.name, badge: session.isDeload ? .deload : .planned,
                summary: SessionSummary.make(day: base, directory: directory),
                showsWhy: false, originButton: nil, startButton: String(localized: "Démarrer la séance", bundle: .module)))
        }
    }

    private static func runSuggestion(_ adjusted: AdjustedSession) -> String? {
        let kinds = adjusted.adjustments.map(\.kind)
        if kinds.contains(.suggestRest) {
            return String(localized: "Surmenage : repos conseillé aujourd'hui, la course peut attendre.", bundle: .module)
        }
        if kinds.contains(.swapIntervalsForEasy) {
            return String(localized: "Fatigue modérée : remplace le fractionné par une sortie facile de même durée.", bundle: .module)
        }
        return nil
    }

    /// « 40 min », « 8 km » ou « 40 min · 8 km » ; `nil` sans cible.
    static func runTarget(_ day: RoutineDay) -> String? {
        var parts: [String] = []
        if let minutes = day.runTargetMinutes {
            parts.append(PulseFormat.duration(minutes: minutes))
        }
        if let km = day.runTargetKm {
            let number = km.formatted(.number.locale(Locale(identifier: "fr_FR")).precision(.fractionLength(0...1)))
            parts.append(String(localized: "\(number) km", bundle: .module))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
