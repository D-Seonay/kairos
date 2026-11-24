import Charts
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'encre de la courbe : la tendance en plein, les pesées plus claires mais à 3:1 contre le papier et la carte (WCAG 1.4.11).
enum WeightInk {
    static let trendOpacity = 1.0
    static let weighInOpacity = 0.6
    static let trend = PulsePalette.ink.opacity(trendOpacity)
    static let weighIn = PulsePalette.ink.opacity(weighInOpacity)
}

/// Le descripteur de graphique audio du poids : la tendance et les pesées, les axes et le résumé dits en français.
enum WeightChartDescriptor {
    static func make(weighed: [WeightDay], line: [StatsPoint], current: Double?, calendar: Calendar, today: Date) -> PulseChartDescriptor {
        let values = weighed.map(\.weightKg) + line.map(\.value)
        let (low, high) = (values.min() ?? 0, values.max() ?? 0)
        return PulseChartDescriptor(
            title: String(localized: "Poids sur 90 jours", bundle: .module),
            summary: ProfileText.weightChartSummary(weighed: weighed, current: current, calendar: calendar, today: today),
            xAxis: .dates(title: String(localized: "Jour", bundle: .module)),
            yAxis: .init(title: String(localized: "Poids, en kilos", bundle: .module), unit: "",
                         range: low < high ? low...high : (low - 1)...(high + 1), valueText: { ProfileText.weightSpoken($0) }),
            series: [.init(name: String(localized: "Tendance", bundle: .module),
                           points: line.map { .init(date: $0.date, y: $0.value) }),
                     .init(name: String(localized: "Pesées", bundle: .module),
                           points: weighed.map { .init(date: $0.date, y: $0.weightKg) })],
            calendar: calendar)
    }
}

/// Les 90 derniers jours : un point par jour pesé, la ligne de la tendance sur 7 jours. Le domaine des dates est épinglé aux 90
/// jours et la zone du graphique rognée, comme les courbes de Stats.
struct WeightChart: View {
    static let days = 90

    let trend: WeightTrend
    let calendar: Calendar
    let today: Date
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180

    var body: some View {
        let weighed = trend.days.filter { domain.contains($0.date) }
        if weighed.isEmpty {
            ProfileEmptyNote(heading: String(localized: "Aucune pesée sur 90 jours", bundle: .module), reason: emptyReason)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                chart(weighed: weighed, line: trend.trendPoints.filter { domain.contains($0.date) })
                legend
            }
        }
    }

    /// Du début du jour, 89 jours avant aujourd'hui, au début de demain.
    private var domain: ClosedRange<Date> {
        let start = calendar.startOfDay(for: today)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? today
        return (calendar.date(byAdding: .day, value: 1 - Self.days, to: start) ?? start)...end
    }

    private var emptyReason: String {
        guard let last = trend.lastMeasured else {
            return String(localized: "ajoute une pesée ou autorise le poids dans Apple Santé", bundle: .module)
        }
        let day = ProfileText.shortDate(last, calendar: calendar, today: today)
        return String(localized: "dernière pesée le \(day)", bundle: .module)
    }

    private func chart(weighed: [WeightDay], line: [StatsPoint]) -> some View {
        let dateLabel = String(localized: "Jour", bundle: .module)
        let weightLabel = String(localized: "Poids, en kilos", bundle: .module)
        let curveName = String(localized: "Courbe", bundle: .module)
        let summary = ProfileText.weightChartSummary(weighed: weighed, current: trend.current, calendar: calendar, today: today)
        return Chart {
            // La courbe est décorative : le résumé et le descripteur disent la tendance, et chaque pesée est lue une fois, avec sa date.
            ForEach(line) { point in
                LineMark(x: .value(dateLabel, point.date, unit: .day), y: .value(weightLabel, point.value),
                         series: .value(curveName, String(localized: "Tendance", bundle: .module)))
                    .foregroundStyle(WeightInk.trend)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                    .accessibilityHidden(true)
            }
            ForEach(weighed) { day in
                let spoken = ProfileText.weightPointSpoken(day, calendar: calendar, today: today)
                PointMark(x: .value(dateLabel, day.date, unit: .day), y: .value(weightLabel, day.weightKg))
                    .foregroundStyle(WeightInk.weighIn)
                    .symbolSize(24)
                    .accessibilityLabel(spoken.label)
                    .accessibilityValue(spoken.value)
            }
        }
        .chartXScale(domain: domain)
        .chartPlotStyle { $0.clipped() }
        .chartYScale(domain: .automatic(includesZero: false))
        .weightAxes(calendar: calendar)
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(summary)
        .accessibilityChartDescriptor(WeightChartDescriptor.make(weighed: weighed, line: line, current: trend.current,
                                                                 calendar: calendar, today: today))
    }

    /// « Pesée » et « Tendance sur 7 jours » côte à côte, l'une sous l'autre quand la largeur manque.
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems }
            VStack(alignment: .leading, spacing: 6) { legendItems }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var legendItems: some View {
        legendItem(String(localized: "Pesée", bundle: .module)) {
            Circle().fill(WeightInk.weighIn).frame(width: 7, height: 7)
        }
        legendItem(String(localized: "Tendance sur 7 jours", bundle: .module)) {
            Capsule().fill(WeightInk.trend).frame(width: 14, height: 2)
        }
    }

    private func legendItem(_ label: String, @ViewBuilder mark: () -> some View) -> some View {
        HStack(spacing: 6) {
            mark()
            Text(label)
                .font(.caption)
                .foregroundStyle(PulsePalette.text2)
        }
    }
}

private extension View {
    /// Les axes des courbes de Stats : filets pointillés, étiquettes grises, dates en « 12 nov. », poids en « 78 kg ».
    func weightAxes(calendar: Calendar) -> some View {
        chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(PulsePalette.line)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(PulsePalette.muted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(PulsePalette.line)
                AxisValueLabel {
                    Text(value.as(Double.self).map { ProfileText.weight($0) } ?? "")
                }
                .foregroundStyle(PulsePalette.muted)
            }
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
    }
}
