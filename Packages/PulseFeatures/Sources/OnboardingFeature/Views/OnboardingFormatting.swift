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
    /// Sept jours, du lundi au dimanche ; un jour sans séance ou à l'identifiant inconnu est un repos.
    static func days(for template: ProgramTemplate) -> [WeekPreviewDay] {
        Weekday.allCases.enumerated().map { index, weekday in
            let dayID = template.suggestedWeek.indices.contains(index) ? template.suggestedWeek[index] : nil
            let kind = dayID.flatMap { id in template.days.first { $0.id == id }?.kind }
            switch kind {
            case .strength: return WeekPreviewDay(weekday: weekday, kind: .strength)
            case .run: return WeekPreviewDay(weekday: weekday, kind: .run)
            case nil: return WeekPreviewDay(weekday: weekday, kind: .rest)
            }
        }
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

/// Une ligne de « Ta ligne de base » : « Variabilité cardiaque — 54 ms ± 9 ».
struct BaselineRow: Equatable {
    let title: String
    let value: String
    let deviation: String?

    /// Les seules lignes pour lesquelles la ligne de base a une valeur.
    static func rows(from baseline: BaselineSummary) -> [BaselineRow] {
        var rows: [BaselineRow] = []
        if let mean = baseline.hrvMeanMs {
            rows.append(BaselineRow(
                title: String(localized: "Variabilité cardiaque", bundle: .module),
                value: PulseFormat.integer(mean, unit: "ms"), deviation: deviation(baseline.hrvDeviationMs)))
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

    /// « Estimé » pour un score issu du check-in, « En calibration (9 nuits) » tant que la ligne de base VFC se construit.
    static func marker(for recovery: DailyRecovery) -> String? {
        if recovery.isEstimated { return String(localized: "Estimé", bundle: .module) }
        if case .calibrating(let nights) = recovery.calibration {
            return String(localized: "En calibration (\(nights) nuits)", bundle: .module)
        }
        return nil
    }
}
