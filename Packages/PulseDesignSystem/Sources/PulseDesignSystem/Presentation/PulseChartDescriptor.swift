import Accessibility
import Foundation
import SwiftUI

/// Le descripteur de graphique audio d'un graphique de l'app : VoiceOver le lit comme un résumé, puis le joue en sons
/// (Audio Graphs) et le détaille point par point. Les axes et les séries sont en français, les dates en toutes lettres
/// (« 28 octobre »), les valeurs avec leur unité dite en toutes lettres (« 80 kilos »).
/// À poser sur un graphique : `.accessibilityChartDescriptor(PulseChartDescriptor(...))`.
public struct PulseChartDescriptor: AXChartDescriptorRepresentable {
    /// L'axe horizontal : des dates, ou des catégories dans un ordre donné.
    public enum XAxis: Sendable {
        case dates(title: String)
        case categories(title: String, names: [String])
    }

    /// L'axe vertical : son titre, l'unité dite en toutes lettres (« kilos », « séances ») et la plage de valeurs.
    public struct YAxis: Sendable {
        public let title: String
        public let unit: String
        public let range: ClosedRange<Double>

        public init(title: String, unit: String, range: ClosedRange<Double>) {
            self.title = title
            self.unit = unit
            self.range = range
        }
    }

    /// La position d'un point sur l'axe horizontal.
    public enum XValue: Sendable {
        case date(Date)
        case category(String)
    }

    /// Un point : sa position sur l'axe horizontal et sa valeur.
    public struct Point: Sendable {
        public let x: XValue
        public let y: Double

        public init(date: Date, y: Double) {
            x = .date(date)
            self.y = y
        }

        public init(category: String, y: Double) {
            x = .category(category)
            self.y = y
        }
    }

    public struct Series: Sendable {
        public let name: String
        public let points: [Point]

        public init(name: String, points: [Point]) {
            self.name = name
            self.points = points
        }
    }

    private let title: String
    private let summary: String
    private let xAxis: XAxis
    private let yAxis: YAxis
    private let series: [Series]
    private let calendar: Calendar

    public init(title: String, summary: String, xAxis: XAxis, yAxis: YAxis, series: [Series], calendar: Calendar = .current) {
        self.title = title
        self.summary = summary
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.series = series
        self.calendar = calendar
    }

    public func makeChartDescriptor() -> AXChartDescriptor {
        let usable = series.map { Series(name: $0.name, points: $0.points.filter { $0.y.isFinite }) }
        return AXChartDescriptor(
            title: title,
            summary: spokenSummary(usable),
            xAxis: makeXAxis(usable),
            yAxis: AXNumericDataAxisDescriptor(
                title: yAxis.title, range: yAxis.range, gridlinePositions: [],
                valueDescriptionProvider: { [unit = yAxis.unit] in Self.speak(value: $0, unit: unit) }
            ),
            series: usable.map(makeSeries)
        )
    }

    /// Le résumé donné, suivi de « Pas assez de données » quand aucune série n'a deux points : une tendance n'existe pas.
    private func spokenSummary(_ usable: [Series]) -> String {
        guard !usable.contains(where: { $0.points.count >= 2 }) else { return summary }
        let notEnough = String(localized: "Pas assez de données.", bundle: .module)
        return summary.isEmpty ? notEnough : "\(summary) \(notEnough)"
    }

    private func makeXAxis(_ usable: [Series]) -> any AXDataAxisDescriptor {
        switch xAxis {
        case .dates(let title):
            let seconds = usable.flatMap(\.points).compactMap { point -> Double? in
                if case .date(let date) = point.x { date.timeIntervalSince1970 } else { nil }
            }
            // Une plage vide (aucun point ou un seul) fait au moins un jour : l'axe reste lisible.
            let lower = seconds.min() ?? 0
            let upper = max(seconds.max() ?? lower, lower + 86_400)
            return AXNumericDataAxisDescriptor(
                title: title, range: lower...upper, gridlinePositions: [],
                valueDescriptionProvider: { [calendar] in
                    PulseSpoken.date(Date(timeIntervalSince1970: $0), calendar: calendar)
                }
            )
        case .categories(let title, let names):
            return AXCategoricalDataAxisDescriptor(title: title, categoryOrder: names)
        }
    }

    private func makeSeries(_ series: Series) -> AXDataSeriesDescriptor {
        let isContinuous: Bool
        if case .dates = xAxis { isContinuous = true } else { isContinuous = false }
        let points = series.points.map { point in
            switch point.x {
            case .date(let date): AXDataPoint(x: date.timeIntervalSince1970, y: point.y)
            case .category(let name): AXDataPoint(x: name, y: point.y)
            }
        }
        return AXDataSeriesDescriptor(name: series.name, isContinuous: isContinuous, dataPoints: points)
    }

    /// « 80 kilos », « 62,5 kilos » ; juste le nombre sans unité.
    static func speak(value: Double, unit: String) -> String {
        let number = PulseFormat.grouped(value, maxFractionDigits: 2)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}
