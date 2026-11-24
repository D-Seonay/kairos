import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Ce que VoiceOver dit du graphique de sommeil de Stats : le résumé de la période et chaque barre.
extension StatsText {
    /// « Sommeil, 30 jours : 7 heures 12 minutes en moyenne, profond 19 %, léger 58 %, paradoxal 23 %, nuit la plus courte
    /// 5 heures 30 minutes le 3 novembre, nuit la plus longue 9 heures le 5 novembre. » Sans phases connues sur la période,
    /// seule la part de profond est dite, comme la tuile « Sommeil moyen ».
    static func sleepSummary(points: [SleepPoint], deepShare: Double?, stageShares: StageShares?, period: StatsPeriod,
                             calendar: Calendar) -> String {
        let title = period.title
        let bucket = period.chartBucket
        let minutes = points.map(\.asleepMinutes)
        let average = durationSpoken(minutes: minutes.isEmpty ? .nan : minutes.reduce(0, +) / Double(minutes.count))
        var text = String(localized: "Sommeil, \(title) : \(average) en moyenne", bundle: .module)
        if let shares = sleepSharesSpoken(deepShare: deepShare, stageShares: stageShares) {
            text += ", " + shares
        }
        if points.count > 1, let shortest = points.min(by: { $0.asleepMinutes < $1.asleepMinutes }),
           let longest = points.max(by: { $0.asleepMinutes < $1.asleepMinutes }) {
            text += ", " + extreme(shortest, isShortest: true, bucket: bucket, calendar: calendar)
            text += ", " + extreme(longest, isShortest: false, bucket: bucket, calendar: calendar)
        }
        return text + "."
    }

    /// « profond 19 %, léger 58 %, paradoxal 23 % » (plus « sans phase 2 % » s'il y en a), dans l'ordre d'empilement des
    /// barres ; « profond 19 % » sans phases connues ; rien sans profond.
    static func sleepSharesSpoken(deepShare: Double?, stageShares: StageShares?) -> String? {
        func percent(_ share: Double) -> String { PulseFormat.integer(share * 100, unit: "%") }
        guard let shares = stageShares else {
            return deepShare.map { String(localized: "profond \(percent($0))", bundle: .module) }
        }
        var parts = [String(localized: "profond \(percent(shares.deep))", bundle: .module),
                     String(localized: "léger \(percent(shares.core))", bundle: .module),
                     String(localized: "paradoxal \(percent(shares.rem))", bundle: .module)]
        if (shares.unspecified * 100).rounded() > 0 {
            parts.append(String(localized: "sans phase \(percent(shares.unspecified))", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }

    private static func extreme(_ point: SleepPoint, isShortest: Bool, bucket: StatsBucket, calendar: Calendar) -> String {
        let duration = durationSpoken(minutes: point.asleepMinutes)
        let date = PulseSpoken.date(point.date, calendar: calendar)
        switch (bucket, isShortest) {
        case (.day, true): return String(localized: "nuit la plus courte \(duration) le \(date)", bundle: .module)
        case (.day, false): return String(localized: "nuit la plus longue \(duration) le \(date)", bundle: .module)
        case (.week, true): return String(localized: "semaine la plus courte \(duration) la semaine du \(date)", bundle: .module)
        case (.week, false): return String(localized: "semaine la plus longue \(duration) la semaine du \(date)", bundle: .module)
        }
    }

    /// « Nuit du 12 novembre » et « 7 heures 12 minutes, dont 1 heure 20 minutes de sommeil profond ».
    static func sleepPointSpoken(point: SleepPoint, bucket: StatsBucket, calendar: Calendar) -> (label: String, value: String) {
        var value = durationSpoken(minutes: point.asleepMinutes)
        if point.hasStages {
            let parts = [(point.deepMinutes, String(localized: "de profond", bundle: .module)),
                         (point.coreMinutes, String(localized: "de léger", bundle: .module)),
                         (point.remMinutes, String(localized: "de paradoxal", bundle: .module)),
                         (point.unspecifiedMinutes, String(localized: "sans phase", bundle: .module))]
                .compactMap { minutes, name -> String? in
                    guard let minutes, minutes.rounded() > 0 else { return nil }
                    return "\(durationSpoken(minutes: minutes)) \(name)"
                }
            if !parts.isEmpty {
                value += String(localized: ", dont \(parts.joined(separator: ", "))", bundle: .module)
            }
            return (nightLabel(point.date, bucket: bucket, calendar: calendar), value)
        }
        if let deep = point.deepMinutes, deep > 0 {
            let duration = durationSpoken(minutes: min(deep, point.asleepMinutes))
            value += String(localized: ", dont \(duration) de sommeil profond", bundle: .module)
        }
        return (nightLabel(point.date, bucket: bucket, calendar: calendar), value)
    }
}
