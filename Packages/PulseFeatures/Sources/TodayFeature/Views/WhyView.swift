import PulseDesignSystem
import PulseDomain
import SwiftUI

/// « Pourquoi cette adaptation » : la lecture de la nuit, ce que le moteur a changé, les signaux du score et la formule,
/// puis les boutons. Poussé dans la pile de l'accueil depuis la carte de récupération ou le bouton « Pourquoi ? ».
struct WhyView: View {
    let model: TodayModel
    /// Lance la séance affichée.
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            if let why = model.why {
                VStack(alignment: .leading, spacing: 20) {
                    ReadingCard(text: why.reading)
                    ChangesSection(changes: why.changes)
                    SignalsSection(signals: why.signals, formula: why.formula, rule: why.rule)
                    ActionButtons(model: model, why: why, onStart: onStart)
                }
                .padding(PulseMetrics.spacing)
            }
        }
        .background(PulsePalette.background)
        .navigationTitle(String(localized: "Pourquoi cette adaptation", bundle: .module))
        .pulseInlineTitle()
    }
}

/// « Lecture de ce matin » sur la carte opale.
private struct ReadingCard: View {
    let text: String

    var body: some View {
        OpalCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Lecture de ce matin", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.opalMuted)
                    .accessibilityAddTraits(.isHeader)
                Text(text)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulsePalette.opalInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(PulsePalette.text)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Ce que le moteur a changé

private struct ChangesSection: View {
    let changes: [WhyContent.Change]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(String(localized: "Ce que le moteur a changé", bundle: .module))
            ObsidianCard {
                VStack(spacing: 0) {
                    ForEach(changes.indices, id: \.self) { index in
                        if index > 0 {
                            Divider().overlay(PulsePalette.line)
                        }
                        ChangeRow(change: changes[index])
                    }
                }
            }
        }
    }
}

/// La pastille (« −4 », « 7,5 », « = »), le titre et ce que l'ajustement change ; empilés aux tailles d'accessibilité.
/// La pastille n'est pas lue : le titre dit déjà la même chose.
private struct ChangeRow: View {
    let change: WhyContent.Change
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            pill
            VStack(alignment: .leading, spacing: 4) {
                Text(change.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                if let detail = change.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var pill: some View {
        let palette = PulsePalette.accent(for: theme)
        return Text(change.pill)
            .font(.system(.footnote, weight: .bold).monospacedDigit())
            .foregroundStyle(Color(palette.accent))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 32)
            .background(palette.soft, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Les signaux

private struct SignalsSection: View {
    let signals: [WhyContent.Signal]
    let formula: String
    let rule: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(sectionTitle)
            ObsidianCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(signals.indices, id: \.self) { index in
                        SignalBar(signal: signals[index])
                    }
                    if !signals.isEmpty {
                        Divider().overlay(PulsePalette.line)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formula)
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(PulsePalette.text)
                        Text(rule)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text2)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var sectionTitle: String {
        signals.count == 2
            ? String(localized: "Les deux signaux", bundle: .module)
            : String(localized: "Les trois signaux", bundle: .module)
    }
}

/// Le titre et la valeur sur une ligne, la barre dessous, colorée par la catégorie que cette valeur atteindrait. La valeur est écrite :
/// la couleur ne porte jamais seule l'information.
private struct SignalBar: View {
    let signal: WhyContent.Signal
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            layout {
                Text(signal.title)
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(signal.score)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(PulsePalette.text)
            }
            track
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(signal.title), \(signal.score) sur 100", bundle: .module))
    }

    private var track: some View {
        let tone = RecoveryCategory(score: Double(signal.score)).tone.color(onOpal: false)
        let fraction = min(1, max(0, Double(signal.score) / 100))
        return Capsule()
            .fill(PulsePalette.surface2)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tone)
                        .frame(width: proxy.size.width * fraction)
                }
            }
    }
}

// MARK: - Boutons

/// « Valider et démarrer » ou la mobilité, « Rétablir la séance d'origine » ou « Revenir à l'ajustée », et le dernier mot.
private struct ActionButtons: View {
    let model: TodayModel
    let why: WhyContent
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let action = why.primaryAction {
                Button(action.title) { start(action) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if let restoreTitle = why.restoreTitle {
                Button(restoreTitle) {
                    Task { await model.toggleOriginalSessionFromWhy() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Text(String(localized: "Tu gardes toujours le dernier mot.", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func start(_ action: WhyContent.Action) {
        switch action {
        case .startSession: onStart()
        case .startMobility: model.startMobility()
        }
    }
}

#if DEBUG
import CheckInFeature
import PulseServices

/// Prépare le modèle de l'aperçu, le rafraîchit (et enregistre `answers` quand les nuits ne suffisent pas), puis montre l'écran
/// dans une pile de navigation.
private struct WhyPreviewHost: View {
    let scenario: HealthScenario
    var answers: [CheckInQuestion: Int] = [:]
    @State private var model: TodayModel?

    var body: some View {
        NavigationStack {
            if let model {
                WhyView(model: model, onStart: {})
            } else {
                ProgressView()
            }
        }
        .task {
            let prepared = await TodayPreviewSupport.model(scenario: scenario, now: TodayPreviewSupport.date(day: 2, hour: 8))
            await prepared.refresh()
            if !answers.isEmpty {
                prepared.checkIn.selection = answers
                await prepared.submitCheckIn()
            }
            model = prepared
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Score mesuré, fatigue") {
    WhyPreviewHost(scenario: .badNight)
}

#Preview("Score estimé") {
    WhyPreviewHost(scenario: .threeNights, answers: [.sleep: 3, .pain: 3, .motivation: 3])
}

#Preview("Surmenage") {
    WhyPreviewHost(scenario: .threeNights, answers: [.sleep: 0, .pain: 1, .motivation: 0])
}
#endif
