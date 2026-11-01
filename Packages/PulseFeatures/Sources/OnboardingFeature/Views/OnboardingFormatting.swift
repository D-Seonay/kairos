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
    /// Sept jours, du lundi au dimanche, tels que l'adoption les placera : les séances glissent hors des jours de repos
    /// imposés (`WeekLayoutArranger`) et une séance sans place disparaît. Un jour sans séance ou à l'identifiant inconnu
    /// est un repos.
    static func days(for template: ProgramTemplate, restWeekdays: [Weekday]) -> [WeekPreviewDay] {
        let kindsByID = Dictionary(template.days.map { ($0.id, $0.kind) }, uniquingKeysWith: { first, _ in first })
        var kindsBySlot: [UUID: WeekPreviewDay.Kind] = [:]
        let layout: [UUID?] = Weekday.allCases.indices.map { index in
            guard template.suggestedWeek.indices.contains(index), let dayID = template.suggestedWeek[index],
                  let kind = kindsByID[dayID] else { return nil }
            let slot = UUID()
            kindsBySlot[slot] = kind == .strength ? .strength : .run
            return slot
        }
        let arranged = WeekLayoutArranger.arrange(layout, restWeekdays: restWeekdays)
        return zip(Weekday.allCases, arranged).map { weekday, slot in
            WeekPreviewDay(weekday: weekday, kind: slot.flatMap { kindsBySlot[$0] } ?? .rest)
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
    /// « Proposition : 3 séances de musculation et 2 sorties par semaine. » ; une part à zéro n'est pas écrite.
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
}
