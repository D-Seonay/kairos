import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Le mois et la série (spec M6 §5, §6) : la série et ses 12 dernières semaines, puis le calendrier du mois et sa légende.
struct MonthView: View {
    @State private var model: MonthModel

    init(model: MonthModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                if let streak = model.streak {
                    StreakCard(streak: streak, weekText: model.currentWeekText)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                calendar
                legend
            }
            .padding(PulseMetrics.spacing)
        }
        .pulseScreenBackground(aura: 0.4)
        .navigationTitle(String(localized: "Mois et série", bundle: .module))
        .pulseInlineTitle()
        .task { await model.load() }
    }

    private var calendar: some View {
        ObsidianCard {
            VStack(spacing: 12) {
                HStack {
                    Button { Task { await model.show(offset: -1) } } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .disabled(!model.canGoBack)
                    .accessibilityLabel(String(localized: "Mois précédent", bundle: .module))
                    .accessibilityIdentifier(PlanningIdentifiers.monthPrevious)
                    Spacer()
                    Text(model.title.capitalized)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { Task { await model.show(offset: 1) } } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .disabled(!model.canGoForward)
                    .accessibilityLabel(String(localized: "Mois suivant", bundle: .module))
                    .accessibilityIdentifier(PlanningIdentifiers.monthNext)
                }
                .foregroundStyle(PulsePalette.text)
                Grid(horizontalSpacing: 4, verticalSpacing: 6) {
                    GridRow {
                        ForEach(Array(model.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PulsePalette.muted)
                                .frame(maxWidth: .infinity)
                                .accessibilityHidden(true)
                        }
                    }
                    ForEach(Array((model.grid?.weeks ?? []).enumerated()), id: \.offset) { _, week in
                        GridRow {
                            ForEach(week) { day in
                                MonthDayCell(day: day, number: model.number(of: day))
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(model.accessibilityText(of: day))
                            }
                        }
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(String(localized: "Séance validée", bundle: .module)) {
                Circle().fill(PulsePalette.ink).frame(width: 10, height: 10)
            }
            legendItem(String(localized: "Prévue", bundle: .module)) {
                Circle().strokeBorder(PulsePalette.ink, lineWidth: 1).frame(width: 10, height: 10)
            }
            legendItem(String(localized: "Deux séances ou record", bundle: .module)) {
                Circle().fill(PulsePalette.signal).frame(width: 5, height: 5)
            }
        }
        .font(.caption)
        .foregroundStyle(PulsePalette.text2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(_ text: String, @ViewBuilder mark: () -> some View) -> some View {
        HStack(spacing: 6) {
            mark()
            Text(text)
        }
    }
}

/// Un jour du calendrier : pastille pleine avec l'icône de la discipline faite, creuse pour celle prévue, point pour deux
/// séances ou un record, cercle pour aujourd'hui.
private struct MonthDayCell: View {
    let day: MonthDay
    let number: String

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if let kind = day.done.first {
                    Circle().fill(PulsePalette.ink)
                    Image(systemName: PlanningText.icon(of: kind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PulsePalette.page)
                } else {
                    if let planned = day.planned {
                        Circle().strokeBorder(PulsePalette.ink.opacity(0.45), lineWidth: 1)
                        Image(systemName: PlanningText.icon(of: planned))
                            .font(.system(size: 11))
                            .foregroundStyle(PulsePalette.text2)
                    } else {
                        Text(number)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(day.isInMonth ? PulsePalette.text : PulsePalette.muted)
                    }
                }
                if day.isToday {
                    Circle().strokeBorder(PulsePalette.ink, lineWidth: 1.5).padding(-3)
                }
            }
            .frame(width: 34, height: 34)
            Circle()
                .fill(day.hasMark ? PulsePalette.signal : .clear)
                .frame(width: 5, height: 5)
        }
        .opacity(day.isInMonth ? 1 : 0.35)
        .frame(maxWidth: .infinity)
    }
}

/// La série : la flamme et son compteur, la semaine en cours, et les 12 dernières semaines (coche réussie, cercle vide ratée,
/// anneau de progression pour la semaine en cours).
struct StreakCard: View {
    let streak: StreakSummary
    let weekText: String

    var body: some View {
        OpalCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(streak.streak > 0 ? PulsePalette.signal : PulsePalette.opalMuted)
                        .accessibilityHidden(true)
                    Text("\(streak.streak)")
                        .font(PulseFont.score(size: 52))
                        .foregroundStyle(PulsePalette.opalInk)
                    Text(String(localized: "semaines d'affilée", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.opalMuted)
                }
                .accessibilityElement(children: .combine)
                Text(weekText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.opalInk)
                HStack(spacing: 0) {
                    ForEach(streak.weeks) { week in
                        mark(week)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(pillarText)
                Text(String(localized: "Une semaine est réussie quand tu fais toutes les séances prévues, courses comprises.",
                            bundle: .module))
                    .font(.caption)
                    .foregroundStyle(PulsePalette.opalMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func mark(_ week: StreakWeek) -> some View {
        if week.isCurrent && !week.isSuccess {
            ZStack {
                Circle().stroke(PulsePalette.opalLine, lineWidth: 3)
                Circle().trim(from: 0, to: week.progress)
                    .stroke(PulsePalette.opalInk, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
        } else if week.isSuccess {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(PulsePalette.opalInk)
        } else {
            Circle().strokeBorder(PulsePalette.opalLine, lineWidth: 1.5).frame(width: 20, height: 20)
        }
    }

    private var pillarText: String {
        let done = streak.weeks.filter(\.isSuccess).count
        return String(localized: "\(done) semaines réussies sur les \(streak.weeks.count) dernières", bundle: .module)
    }
}
