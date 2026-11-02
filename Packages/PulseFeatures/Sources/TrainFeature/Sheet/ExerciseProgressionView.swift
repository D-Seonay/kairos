import PulseDesignSystem
import SwiftUI

/// L'onglet « Progression » : 1RM estimé et meilleure série, courbe sur 90 jours, incrément de l'exercice, dernières séances.
struct ProgressionPane: View {
    let model: ExerciseSheetModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
            indicators
            chartCard
            IncrementCard(model: model)
            sessions
        }
    }

    // MARK: - Indicateurs

    private var indicators: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            Indicator(title: String(localized: "1RM estimé", bundle: .module), value: oneRepMaxText,
                      detail: changeText, detailColor: changeColor)
            Indicator(title: String(localized: "Meilleure série", bundle: .module), value: bestSetText,
                      detail: model.bestSet.map { model.dateText($0.date) }, detailColor: PulsePalette.text2)
        }
    }

    private var oneRepMaxText: String {
        model.currentOneRepMax.map { "\(PulseFormat.decimal($0, maxFractionDigits: 1)) kg" } ?? "—"
    }

    /// « +2,5 kg en 30 jours » ; rien sans séance d'il y a 30 jours ou plus.
    private var changeText: String? {
        guard let change = model.oneRepMaxChange30Days else { return nil }
        let sign = change > 0 ? "+" : (change < 0 ? "\u{2212}" : "")
        return String(localized: "\(sign)\(PulseFormat.decimal(abs(change), maxFractionDigits: 1)) kg en 30 jours", bundle: .module)
    }

    private var changeColor: Color {
        guard let change = model.oneRepMaxChange30Days else { return PulsePalette.text2 }
        return change > 0 ? PulsePalette.ok : (change < 0 ? PulsePalette.bad : PulsePalette.text2)
    }

    /// « 72,5 × 5 », « −15 × 8 » assisté ; « 12 répétitions » sans charge ; « — » sans série.
    private var bestSetText: String {
        model.bestSet?.text ?? "—"
    }

    // MARK: - Courbe

    private var chartCard: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "1RM estimé, 90 jours", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Text(String(localized: "Brzycki", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(PulsePalette.muted)
                }
                if let summary = model.chartSummary {
                    ExerciseProgressionChart(points: model.chart, summary: summary)
                } else {
                    Text(String(localized: "Aucune séance de charge sur 90 jours : la courbe apparaîtra avec la prochaine.",
                                bundle: .module))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
    }

    // MARK: - Séances

    @ViewBuilder
    private var sessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SheetSectionTitle(text: String(localized: "Dernières séances", bundle: .module))
            if model.recentSessions.isEmpty {
                Text(String(localized: "Aucune séance enregistrée avec cet exercice.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            } else {
                ObsidianCard {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(model.recentSessions) { line in
                            SessionLineRow(line: line, dateText: model.dateText(line.date))
                        }
                    }
                }
            }
        }
    }
}

/// Une carte de chiffre clé : intitulé, valeur, détail.
private struct Indicator: View {
    let title: String
    let value: String
    let detail: String?
    let detailColor: Color

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                Text(value)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(PulsePalette.text)
                    .minimumScaleFactor(0.7)
                if let detail {
                    Text(detail)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(detailColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

/// « 26 octobre · 72,5 × 5 · RPE 8 », le tonnage à droite et la mention « record » en or.
private struct SessionLineRow: View {
    let line: ExerciseHistoryLine
    let dateText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: line.hasRecord ? "trophy.fill" : "dumbbell.fill")
                .foregroundStyle(line.hasRecord ? PulsePalette.gold : PulsePalette.text2)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: "\(tonnageText) kg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                if line.hasRecord {
                    Text(String(localized: "record", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(PulsePalette.gold)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tonnageText: String {
        line.tonnageKg.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "fr_FR")))
    }

    /// « 70 × 5 · 5 · RPE 8,5 ».
    private var details: String {
        guard let rpe = line.maxRPE else { return line.setsText }
        return String(localized: "\(line.setsText) · RPE \(PulseFormat.decimal(rpe, maxFractionDigits: 1))", bundle: .module)
    }
}

/// Le réglage de l'incrément de charge de l'exercice : de 0,25 à 20 kg par pas de 0,25 kg.
private struct IncrementCard: View {
    let model: ExerciseSheetModel

    var body: some View {
        ObsidianCard {
            Stepper(value: incrementBinding, in: 0.25...20, step: 0.25) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Incrément de charge", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                    Text(verbatim: "\(PulseFormat.decimal(model.increment, maxFractionDigits: 2)) kg")
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            .frame(minHeight: 44)
        }
    }

    private var incrementBinding: Binding<Double> {
        Binding(get: { model.increment }, set: { kg in Task { await model.setIncrement(kg) } })
    }
}
