import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Conversions entre le poids stocké (toujours en kg) et le poids affiché dans l'unité du profil.
enum WeightUnits {
    static let kilogramsPerPound = 0.45359237

    static func displayValue(kilograms: Double, unit: WeightUnit) -> Double {
        unit == .lb ? kilograms / kilogramsPerPound : kilograms
    }

    static func kilograms(fromDisplay value: Double, unit: WeightUnit) -> Double {
        unit == .lb ? value * kilogramsPerPound : value
    }
}

/// Le choix « Aucune » des douleurs : une pilule de plus que les zones du domaine, qui les efface.
enum PainChoice: Hashable {
    case area(PainArea)
    case none

    static func selection(for areas: [PainArea]) -> Set<PainChoice> {
        areas.isEmpty ? [.none] : Set(areas.map(PainChoice.area))
    }

    /// « Aucune » touchée alors que des zones sont cochées les efface ; une zone touchée décoche « Aucune ».
    static func areas(from selection: Set<PainChoice>, previous: [PainArea]) -> [PainArea] {
        if selection.contains(.none), !previous.isEmpty { return [] }
        return PainArea.allCases.filter { selection.contains(.area($0)) }
    }
}

/// Un jour de la semaine suggérée d'un modèle, pour l'aperçu L à D de sa carte.
struct WeekPreviewDay: Equatable {
    enum Kind: Equatable {
        case strength
        case run
        case rest
    }

    let weekday: Weekday
    let kind: Kind
}

enum ProgramWeekPreview {
    /// Sept jours, du lundi au dimanche, lus sur le programme tel que l'adoption le donne : séances glissées hors des repos
    /// imposés, sorties du curseur ajoutées. Un jour sans séance ou à l'identifiant inconnu est un repos.
    static func days(of program: Program) -> [WeekPreviewDay] {
        let kindsByID = Dictionary(program.days.map { ($0.id, $0.kind) }, uniquingKeysWith: { first, _ in first })
        return Weekday.allCases.map { weekday in
            guard program.weekLayout.indices.contains(weekday.index), let dayID = program.weekLayout[weekday.index],
                  let kind = kindsByID[dayID] else { return WeekPreviewDay(weekday: weekday, kind: .rest) }
            return WeekPreviewDay(weekday: weekday, kind: kind == .strength ? .strength : .run)
        }
    }

    /// Le nombre de séances réellement placées dans la semaine.
    static func sessionCount(_ days: [WeekPreviewDay]) -> Int {
        days.filter { $0.kind != .rest }.count
    }

    /// « Lundi : musculation, mardi : repos, … », lu par VoiceOver à la place des sept initiales.
    static func accessibilityLabel(for days: [WeekPreviewDay]) -> String {
        days.map { "\($0.weekday.onboardingName) : \($0.kind.localizedName)" }.joined(separator: ", ")
    }
}

extension WeekPreviewDay.Kind {
    /// Le pictogramme qui double la couleur de l'aperçu : un haltère, un coureur ; `nil` pour un repos, tracé en pointillés.
    var systemImage: String? {
        switch self {
        case .strength: "dumbbell.fill"
        case .run: "figure.run"
        case .rest: nil
        }
    }

    var localizedName: String {
        switch self {
        case .strength: String(localized: "musculation", bundle: .module)
        case .run: String(localized: "course", bundle: .module)
        case .rest: String(localized: "repos", bundle: .module)
        }
    }
}

extension Weekday {
    var onboardingInitial: String {
        switch self {
        case .monday: String(localized: "L", bundle: .module, comment: "Initiale de lundi")
        case .tuesday: String(localized: "M", bundle: .module, comment: "Initiale de mardi")
        case .wednesday: String(localized: "M", bundle: .module, comment: "Initiale de mercredi")
        case .thursday: String(localized: "J", bundle: .module, comment: "Initiale de jeudi")
        case .friday: String(localized: "V", bundle: .module, comment: "Initiale de vendredi")
        case .saturday: String(localized: "S", bundle: .module, comment: "Initiale de samedi")
        case .sunday: String(localized: "D", bundle: .module, comment: "Initiale de dimanche")
        }
    }

    var onboardingName: String {
        switch self {
        case .monday: String(localized: "Lundi", bundle: .module)
        case .tuesday: String(localized: "Mardi", bundle: .module)
        case .wednesday: String(localized: "Mercredi", bundle: .module)
        case .thursday: String(localized: "Jeudi", bundle: .module)
        case .friday: String(localized: "Vendredi", bundle: .module)
        case .saturday: String(localized: "Samedi", bundle: .module)
        case .sunday: String(localized: "Dimanche", bundle: .module)
        }
    }
}

extension PainArea {
    var onboardingName: String {
        switch self {
        case .shoulders: String(localized: "Épaules", bundle: .module)
        case .lowerBack: String(localized: "Lombaires", bundle: .module)
        case .knees: String(localized: "Genoux", bundle: .module)
        case .wrists: String(localized: "Poignets", bundle: .module)
        }
    }
}

/// Une ligne de « Ta ligne de base » : « Variabilité cardiaque — 54 ms ± 9 », ou la VFC qui attend sa ligne de base.
struct BaselineRow: Equatable {
    let title: String
    let value: String
    let deviation: String?
    /// Vrai pour la VFC dont la ligne de base n'existe pas encore : le texte explique l'attente au lieu de donner une mesure.
    var isPending = false

    /// Le nombre de nuits avec SDNN valide qu'il faut pour que la VFC compte dans le score (`HRVBaseline.minimumNights`).
    static let hrvNightsNeeded = 5

    /// Les seules lignes pour lesquelles la ligne de base a une valeur. Un score mesuré sans VFC (`recovery.missingFactors`)
    /// qui n'a pas encore ses 5 nuits garde sa ligne VFC, en attente : « ligne de base en cours, 3 sur 5 nuits ».
    static func rows(from baseline: BaselineSummary, recovery: DailyRecovery? = nil) -> [BaselineRow] {
        var rows: [BaselineRow] = []
        if let nights = pendingHRVNights(recovery) {
            rows.append(BaselineRow(
                title: hrvTitle,
                value: String(localized: "ligne de base en cours, \(nights) sur \(hrvNightsNeeded) nuits", bundle: .module),
                deviation: nil, isPending: true))
        } else if let mean = baseline.hrvMeanMs {
            rows.append(BaselineRow(
                title: hrvTitle, value: PulseFormat.integer(mean, unit: "ms"), deviation: deviation(baseline.hrvDeviationMs)))
        }
        if let mean = baseline.restingHeartRateMean {
            rows.append(BaselineRow(
                title: String(localized: "Fréquence au repos", bundle: .module),
                value: PulseFormat.integer(mean, unit: "bpm"), deviation: deviation(baseline.restingHeartRateDeviation)))
        }
        if let minutes = baseline.sleepMeanMinutes {
            rows.append(BaselineRow(
                title: String(localized: "Sommeil moyen", bundle: .module),
                value: PulseFormat.duration(minutes: minutes), deviation: nil))
        }
        return rows
    }

    /// Les nuits comptées pour la VFC quand le score mesuré s'est passé d'elle faute de ligne de base ; sinon `nil`.
    static func pendingHRVNights(_ recovery: DailyRecovery?) -> Int? {
        guard let recovery, !recovery.isEstimated, recovery.missingFactors.contains(.hrv),
              case .calibrating(let nights) = recovery.calibration, nights < hrvNightsNeeded else { return nil }
        return nights
    }

    private static var hrvTitle: String {
        String(localized: "Variabilité cardiaque", bundle: .module)
    }

    private static func deviation(_ value: Double?) -> String? {
        value.map { "± \(PulseFormat.integer($0, unit: nil))" }
    }
}

enum OnboardingCopy {
    /// « Proposition : 3 séances de musculation et 2 sorties par semaine. » ; une part à zéro n'est pas écrite. Les nombres
    /// sont ceux de `OnboardingModel.weekProposal` : la semaine que l'adoption du modèle recommandé donnera.
    static func proposal(strength: Int, runs: Int) -> String {
        let strengthPart = String(localized: "\(strength) séances de musculation", bundle: .module)
        let runsPart = String(localized: "\(runs) sorties", bundle: .module)
        switch (strength > 0, runs > 0) {
        case (true, true): return String(localized: "Proposition : \(strengthPart) et \(runsPart) par semaine.", bundle: .module)
        case (true, false): return String(localized: "Proposition : \(strengthPart) par semaine.", bundle: .module)
        case (false, true): return String(localized: "Proposition : \(runsPart) par semaine.", bundle: .module)
        case (false, false): return ""
        }
    }

    /// Pourquoi le check-in remplace le score mesuré : Apple Santé ignoré à l'écran 2, ou pas assez de nuits pour la ligne de base.
    static func calibrationExplanation(healthSkipped: Bool) -> String {
        if healthSkipped {
            return String(
                localized: """
                    Sans Apple Santé, Pulse estime ta récupération avec trois questions. Tu pourras autoriser l'accès plus tard \
                    dans Réglages › Santé.
                    """,
                bundle: .module)
        }
        return String(
            localized: """
                Pulse n'a pas assez de nuits pour mesurer ta récupération. Trois questions donnent une première estimation, \
                qu'un score mesuré remplacera dès que ta ligne de base sera prête.
                """,
            bundle: .module)
    }

    /// « Estimé » pour un score issu du check-in, « En calibration (9 nuits) » tant que la ligne de base VFC se construit.
    static func marker(for recovery: DailyRecovery) -> String? {
        if recovery.isEstimated { return String(localized: "Estimé", bundle: .module) }
        if case .calibrating(let nights) = recovery.calibration {
            return String(localized: "En calibration (\(nights) nuits)", bundle: .module)
        }
        return nil
    }

    // MARK: - VoiceOver

    /// L'unité d'une mesure saisie, pour la dire après le titre du champ.
    enum MeasureUnit: Equatable {
        case centimeters
        case kilograms
        case pounds

        init(_ weightUnit: WeightUnit) {
            self = weightUnit == .lb ? .pounds : .kilograms
        }

        /// « centimètres », « kilos », « livres ».
        var spokenName: String {
            switch self {
            case .centimeters: String(localized: "centimètres", bundle: .module)
            case .kilograms: String(localized: "kilos", bundle: .module)
            case .pounds: String(localized: "livres", bundle: .module)
            }
        }
    }

    /// « Ton score est prêt : 58 sur 100, fatigue modérée », suivi de « estimé » pour un score issu du check-in.
    static func scoreReadyAnnouncement(recovery: DailyRecovery) -> String {
        var text = String(localized: "Ton score est prêt : \(scoreSummary(recovery))", bundle: .module)
        if recovery.isEstimated { text += ", " + estimatedWord }
        return text
    }

    /// « Ta récupération ce matin : 58 sur 100, fatigue modérée, estimé » : le titre, la jauge, la catégorie et la pastille
    /// d'état lus d'un seul élément. Une ligne de base en construction se dit « en calibration, 9 nuits ».
    static func scoreAccessibility(recovery: DailyRecovery) -> String {
        var text = String(localized: "Ta récupération ce matin : \(scoreSummary(recovery))", bundle: .module)
        if recovery.isEstimated {
            text += ", " + estimatedWord
        } else if case .calibrating(let nights) = recovery.calibration {
            let count = PulseSpoken.count(nights, singular: String(localized: "nuit", bundle: .module),
                                          plural: String(localized: "nuits", bundle: .module))
            text += ", " + String(localized: "en calibration, \(count)", bundle: .module)
        }
        return text
    }

    /// « Taille, en centimètres », « Poids actuel, en kilos » : l'unité du champ, que l'écran affiche à côté de la saisie.
    static func measureLabel(title: String, unit: MeasureUnit) -> String {
        String(localized: "\(title), en \(unit.spokenName)", bundle: .module)
    }

    /// « 3 séances par semaine » pour la pilule « 3 ».
    static func sessionsPerWeekLabel(_ count: Int) -> String {
        let sessions = PulseSpoken.count(count, singular: String(localized: "séance", bundle: .module),
                                         plural: String(localized: "séances", bundle: .module))
        return String(localized: "\(sessions) par semaine", bundle: .module)
    }

    private static var estimatedWord: String {
        String(localized: "estimé", bundle: .module)
    }

    /// « 58 sur 100, fatigue modérée » : le score arrondi et borné à 0…100, puis la catégorie en minuscules.
    private static func scoreSummary(_ recovery: DailyRecovery) -> String {
        let score = recovery.score.isFinite ? Int(min(max(recovery.score, 0), 100).rounded()) : 0
        let category = recovery.category.localizedName.lowercased()
        return String(localized: "\(PulseSpoken.outOf(score, 100)), \(category)", bundle: .module)
    }
}
