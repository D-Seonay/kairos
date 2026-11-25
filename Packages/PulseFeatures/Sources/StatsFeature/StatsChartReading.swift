import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// La lecture d'un graphique sous le doigt : où tracer la règle, la date et les valeurs écrites dans l'annotation, et la même
/// lecture dite par VoiceOver.
struct StatsChartReading: Equatable {
    /// La position de la règle sur l'axe des dates : la date du point, ou le milieu de son grain quand la marque couvre un jour
    /// ou une semaine (Swift Charts y pose les points et le centre des barres).
    let date: Date
    /// « 12 nov. », « Nuit du 12 nov. », « Semaine du 9 nov. ».
    let title: String
    /// Une valeur par ligne, avec son unité : « 56 ms », « Ligne de base 54 ms ».
    let lines: [String]
    /// « Nuit du 12 novembre, 56 millisecondes, ligne de base 54 millisecondes ».
    let spoken: String
}

/// Les lectures des graphiques à axe de dates des Stats : le point le plus proche du doigt, puis ses textes, aux formats de
/// `StatsText`. Des fonctions pures, testées.
enum StatsChartReadings {
    /// L'élément dont la marque est la plus proche de `date` : son milieu de grain quand `unit` est donné, sa date sinon. `nil`
    /// sans élément.
    static func nearest<Item>(_ items: [Item], to date: Date, unit: Calendar.Component?, calendar: Calendar,
                              at itemDate: (Item) -> Date) -> Item? {
        items.min { lhs, rhs in
            let left = abs(anchor(itemDate(lhs), unit: unit, calendar: calendar).timeIntervalSince(date))
            let right = abs(anchor(itemDate(rhs), unit: unit, calendar: calendar).timeIntervalSince(date))
            return left < right
        }
    }

    /// Le milieu du grain qui commence à `start`, ou `start` lui-même sans grain.
    static func anchor(_ start: Date, unit: Calendar.Component?, calendar: Calendar) -> Date {
        guard let unit, let end = calendar.date(byAdding: unit, value: 1, to: start) else { return start }
        return start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    }

    /// L'unité de grain d'un graphique : un jour ou une semaine.
    static func unit(of bucket: StatsBucket) -> Calendar.Component {
        bucket == .day ? .day : .weekOfYear
    }

    // MARK: Titres

    /// « 12 nov. » par jour, « Semaine du 9 nov. » par semaine.
    static func bucketTitle(_ date: Date, bucket: StatsBucket, calendar: Calendar) -> String {
        let day = StatsText.dayMonth(date, calendar: calendar, month: .abbreviated)
        return bucket == .day ? day : String(localized: "Semaine du \(day)", bundle: .module)
    }

    /// « Nuit du 12 nov. » par jour, « Semaine du 9 nov. » par semaine.
    static func nightTitle(_ date: Date, bucket: StatsBucket, calendar: Calendar) -> String {
        guard bucket == .day else { return bucketTitle(date, bucket: bucket, calendar: calendar) }
        let day = StatsText.dayMonth(date, calendar: calendar, month: .abbreviated)
        return String(localized: "Nuit du \(day)", bundle: .module)
    }

    // MARK: Lectures

    /// La courbe du ratio : « 12 nov. », « Ratio 1,12 ». Les points n'ont pas de grain : la règle tombe sur le jour.
    static func ratio(_ points: [StatsPoint], at date: Date, calendar: Calendar) -> StatsChartReading? {
        guard let point = nearest(points, to: date, unit: nil, calendar: calendar, at: \.date) else { return nil }
        let value = PulseFormat.decimal(point.value, maxFractionDigits: 2)
        let spoken = StatsText.ratioPointSpoken(point, calendar: calendar)
        return StatsChartReading(date: point.date, title: StatsText.dayMonth(point.date, calendar: calendar, month: .abbreviated),
                                 lines: [String(localized: "Ratio \(value)", bundle: .module)],
                                 spoken: "\(spoken.label), \(spoken.value)")
    }

    /// Les barres de charge : « Semaine du 9 nov. », puis chaque discipline chargée (« Musculation 2 140 »), ou « Aucune
    /// charge ».
    static func load(_ bars: [LoadBar], at date: Date, bucket: StatsBucket, calendar: Calendar) -> StatsChartReading? {
        let unit = unit(of: bucket)
        guard let bar = nearest(bars, to: date, unit: unit, calendar: calendar, at: \.start) else { return nil }
        let parts = [(StatsText.strengthName, bar.strength), (StatsText.runName, bar.run), (StatsText.rideName, bar.ride)]
            .filter { $0.1 > 0 }
        let none = String(localized: "Aucune charge", bundle: .module)
        let lines = parts.isEmpty ? [none] : parts.map { "\($0.0) \(StatsText.number($0.1))" }
        let when = StatsText.bucketLabel(bar.start, bucket: bucket, calendar: calendar)
        let spokenParts = parts.isEmpty ? [none.lowercased()] : parts.map { "\($0.0) \(StatsText.number($0.1))" }
        return StatsChartReading(date: anchor(bar.start, unit: unit, calendar: calendar),
                                 title: bucketTitle(bar.start, bucket: bucket, calendar: calendar), lines: lines,
                                 spoken: ([when] + spokenParts).joined(separator: ", "))
    }

    /// La VFC ou la FC au repos : « Nuit du 12 nov. », « 56 ms », « Ligne de base 54 ms ».
    static func baseline(_ points: [BaselinePoint], measure: BiometricMeasure, at date: Date, bucket: StatsBucket,
                         calendar: Calendar) -> StatsChartReading? {
        let unit = unit(of: bucket)
        guard let point = nearest(points, to: date, unit: unit, calendar: calendar, at: \.date) else { return nil }
        var lines = [PulseFormat.integer(point.value, unit: measure.unitSymbol)]
        if let baseline = point.baseline {
            let value = PulseFormat.integer(baseline, unit: measure.unitSymbol)
            lines.append(String(localized: "Ligne de base \(value)", bundle: .module))
        }
        let spoken = StatsText.baselinePointSpoken(measure: measure, point: point, bucket: bucket, calendar: calendar)
        return StatsChartReading(date: anchor(point.date, unit: unit, calendar: calendar),
                                 title: nightTitle(point.date, bucket: bucket, calendar: calendar), lines: lines,
                                 spoken: "\(spoken.label), \(spoken.value)")
    }

    /// Le sommeil : « Nuit du 12 nov. », « 7 h 12 », puis chaque phase (« Profond 1 h 20 ») ; une nuit d'avant les phases ne
    /// donne que le profond.
    static func sleep(_ points: [SleepPoint], at date: Date, bucket: StatsBucket, calendar: Calendar) -> StatsChartReading? {
        let unit = unit(of: bucket)
        guard let point = nearest(points, to: date, unit: unit, calendar: calendar, at: \.date) else { return nil }
        let stages: [(String, Double?)] = point.hasStages
            ? [(SleepStage.deep.displayName, point.deepMinutes), (SleepStage.core.displayName, point.coreMinutes),
               (SleepStage.rem.displayName, point.remMinutes),
               (String(localized: "Sans phase", bundle: .module), point.unspecifiedMinutes)]
            : [(SleepStage.deep.displayName, point.deepMinutes.map { min($0, point.asleepMinutes) })]
        let stageLines = stages.compactMap { name, minutes -> String? in
            guard let minutes, minutes.rounded() > 0 else { return nil }
            return "\(name) \(StatsText.duration(minutes: minutes))"
        }
        let spoken = StatsText.sleepPointSpoken(point: point, bucket: bucket, calendar: calendar)
        return StatsChartReading(date: anchor(point.date, unit: unit, calendar: calendar),
                                 title: nightTitle(point.date, bucket: bucket, calendar: calendar),
                                 lines: [StatsText.duration(minutes: point.asleepMinutes)] + stageLines,
                                 spoken: "\(spoken.label), \(spoken.value)")
    }
}

extension BiometricMeasure {
    /// « ms », « bpm » : l'unité écrite, comme sur l'axe et dans les tuiles.
    var unitSymbol: String {
        switch self {
        case .hrv: "ms"
        case .restingHeartRate: "bpm"
        }
    }
}
