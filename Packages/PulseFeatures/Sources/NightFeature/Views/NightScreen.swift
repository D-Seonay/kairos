import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'écran Nuit (spec sommeil §6.3) : le titre de la nuit et ‹ ›, la durée endormie, l'endormissement et le réveil,
/// l'hypnogramme, les autres blocs comptés, puis la répartition par phase (ou la phrase qui dit que la source n'en donne pas).
public struct NightScreen: View {
    private let model: NightModel

    public init(model: NightModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                if let detail = model.current {
                    NightHeader(model: model, night: detail.night)
                    SummaryCard(detail: detail, goalMinutes: model.goalMinutes, calendar: model.calendar)
                    HypnogramCard(night: detail.night, calendar: model.calendar)
                    if detail.night.hasStages {
                        StageBreakdownList(rows: NightText.breakdownRows(detail))
                    } else {
                        NoteCard(text: NightText.noStagesNote)
                    }
                } else if model.hasLoaded {
                    NoteCard(text: NightText.emptyNote)
                } else {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Chargement des nuits", bundle: .module))
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(PulseMetrics.spacing)
        }
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(String(localized: "Nuit", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareCardButton(content: model.shareContent)
            }
        }
        .accessibilityIdentifier(NightIdentifiers.screen)
        .task {
            if !model.hasLoaded { await model.load() }
        }
    }
}

/// « Nuit du 19 au 20 nov. » entre ‹ et › ; chaque bouton dit la nuit qu'il ouvre.
private struct NightHeader: View {
    let model: NightModel
    let night: NightSleep

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: model.goBack) {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!model.canGoBack)
            .accessibilityLabel(navigationLabel(previous: true))
            .accessibilityIdentifier(NightIdentifiers.previous)
            Text(NightText.title(night, calendar: model.calendar))
                .font(PulseFont.title(.title2, weight: .semibold))
                .foregroundStyle(PulsePalette.text)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(NightText.spokenTitle(night, calendar: model.calendar))
                .accessibilityAddTraits(.isHeader)
            Button(action: model.goForward) {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!model.canGoForward)
            .accessibilityLabel(navigationLabel(previous: false))
            .accessibilityIdentifier(NightIdentifiers.next)
        }
        .foregroundStyle(PulsePalette.text)
    }

    private func navigationLabel(previous: Bool) -> String {
        let target = previous ? model.previous : model.next
        guard let target else {
            return previous
                ? String(localized: "Aucune nuit précédente", bundle: .module)
                : String(localized: "Aucune nuit suivante", bundle: .module)
        }
        let title = NightText.spokenTitle(target.night, calendar: model.calendar)
        return previous
            ? String(localized: "Nuit précédente, \(title)", bundle: .module)
            : String(localized: "Nuit suivante, \(title)", bundle: .module)
    }
}

/// La durée endormie en grand, puis l'endormissement, le réveil et les réveils, l'écart à l'objectif et la régularité du coucher.
private struct SummaryCard: View {
    let detail: NightDetail
    let goalMinutes: Int
    let calendar: Calendar

    private var night: NightSleep { detail.night }

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Temps endormi", bundle: .module))
                    .pulseEyebrow(PulsePalette.text2)
                Text(PulseFormat.duration(minutes: night.asleepMinutes))
                    .font(PulseFont.value(.largeTitle, weight: .regular))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityLabel(NightText.spokenMinutes(night.asleepMinutes))
                    .accessibilityAddTraits(.isHeader)
                Text(NightText.times(night, calendar: calendar))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(NightText.goalGap(asleepMinutes: night.asleepMinutes, goalMinutes: goalMinutes))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(NightText.spokenGoalGap(asleepMinutes: night.asleepMinutes, goalMinutes: goalMinutes))
                if let regularity = detail.bedtimeRegularityMinutes {
                    Text(NightText.regularity(minutes: regularity))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(NightText.spokenRegularity(minutes: regularity))
                }
            }
        }
    }
}

/// Une phrase seule dans une carte : nuit sans phases, ou aucune nuit enregistrée.
private struct NoteCard: View {
    let text: String

    var body: some View {
        ObsidianCard {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
