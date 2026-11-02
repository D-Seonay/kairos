import Foundation
import PulseDomain
import PulseServices

/// Tout ce que dit l'écran « Pourquoi » : la lecture de la nuit en français, une ligne par ajustement, les signaux du score avec
/// la formule aux poids appliqués, la règle de la catégorie et les boutons. Une fonction pure, sans vue ni horloge.
struct WhyContent: Equatable, Sendable {
    /// Un ajustement : la pastille (« −4 », « 7,5 »), son titre et, s'il y a lieu, ce qu'il change en pratique.
    struct Change: Equatable, Sendable {
        var pill: String
        var title: String
        var detail: String?
    }

    /// Un signal du score et sa valeur de 0 à 100 : une mesure de la nuit, ou une réponse du check-in.
    struct Signal: Equatable, Sendable {
        var title: String
        var score: Int
    }

    enum Action: Equatable, Sendable {
        case startSession, startMobility

        var title: String {
            switch self {
            case .startSession: String(localized: "Valider et démarrer", bundle: .module)
            case .startMobility: String(localized: "Démarrer 20 min de mobilité", bundle: .module)
            }
        }
    }

    var reading: String
    var changes: [Change]
    var signals: [Signal]
    var formula: String
    var rule: String
    var primaryAction: Action?
    var restoreTitle: String?

    /// `checkIn` : le check-in du jour, qui sert à lire un score estimé.
    static func make(recovery: DailyRecovery, session: TodaySession, checkIn: CheckIn?, directory: ExerciseDirectory) -> WhyContent {
        let signals = WhySignals.make(recovery: recovery, checkIn: checkIn)
        return WhyContent(
            reading: WhyReading.make(recovery: recovery, session: session),
            changes: WhyChanges.make(recovery: recovery, session: session, directory: directory),
            signals: signals.signals,
            formula: signals.formula,
            rule: rule(for: recovery.category),
            primaryAction: primaryAction(for: session),
            restoreTitle: restoreTitle(for: session))
    }

    // MARK: - Règle

    static func rule(for category: RecoveryCategory) -> String {
        switch category {
        case .optimal:
            String(localized: "À 90 et plus, la séance prévue reste telle quelle.", bundle: .module)
        case .normal:
            String(localized: "Entre 65 et 89, la séance reste la même, avec 15 secondes de repos en plus entre les séries.",
                   bundle: .module)
        case .moderateFatigue:
            String(localized: """
                Entre 40 et 64, la séance perd 20 % de son volume, l'effort est plafonné à RPE 7,5 et les repos \
                s'allongent de 45 secondes.
                """, bundle: .module)
        case .overreached:
            String(localized: "Sous 40, la séance laisse place à 20 minutes de mobilité ou à du repos, au choix.", bundle: .module)
        }
    }

    // MARK: - Boutons

    /// La mobilité quand le surmenage a remplacé la séance, « Valider et démarrer » pour toute autre séance de musculation ;
    /// rien un jour de repos, de course ou sans programme.
    private static func primaryAction(for session: TodaySession) -> Action? {
        guard case .strength = session.plannedDay else { return nil }
        if session.status == .adjusted, session.adjusted?.isReplacedByMobility == true {
            return .startMobility
        }
        return .startSession
    }

    private static func restoreTitle(for session: TodaySession) -> String? {
        switch session.status {
        case .planned: nil
        case .adjusted: String(localized: "Rétablir la séance d'origine", bundle: .module)
        case .restored: String(localized: "Revenir à l'ajustée", bundle: .module)
        }
    }

    // MARK: - Aides communes

    /// « A », « A et B », « A, B et C ».
    static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(Locale(identifier: "fr_FR")))
    }

    /// L'entier le plus proche, comme l'affiche la jauge ; 0 pour une valeur non finie.
    static func rounded(_ value: Double) -> Int {
        Int(exactly: value.rounded()) ?? 0
    }
}
