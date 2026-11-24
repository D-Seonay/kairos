import PulseDesignSystem
import SwiftUI

#if os(iOS)
import UIKit
#endif

/// La feuille « 20 min de mobilité » : un minuteur pausable, cinq consignes, et la précision que rien n'est enregistré.
///
/// Le minuteur lit l'horloge murale (`Date.now` au toucher, la date du `TimelineView`) : une horloge fixée par `-PulseNow`
/// figerait le décompte. C'est de l'interface, toute la logique reste dans `MobilityTimer`.
public struct MobilitySheet: View {
    @State private var timer = MobilityTimer()
    @ScaledMetric(relativeTo: .largeTitle) private var digitSize: CGFloat = 72
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init() {}

    public var body: some View {
        ZStack {
            PulsePalette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: PulseMetrics.spacing) {
                    Text(String(localized: "20 min de mobilité", bundle: .module))
                        .font(PulseFont.title(.title))
                        .foregroundStyle(PulsePalette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    clock
                    guide
                    Text(Self.notRecordedNote)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(String(localized: "Fermer", bundle: .module)) { dismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(PulseMetrics.spacing)
            }
        }
        // Un glissement ne ferme pas la feuille pendant le décompte : seul « Fermer » le fait. L'écran reste allumé tant qu'il tourne.
        .interactiveDismissDisabled(timer.isRunning)
        .onChange(of: timer.isRunning) { _, running in Self.keepScreenAwake(running) }
        .onDisappear { Self.keepScreenAwake(false) }
    }

    /// Empêche (ou rend) la mise en veille de l'écran. Sans effet hors iOS.
    private static func keepScreenAwake(_ awake: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = awake
        #endif
    }

    /// Le minuteur est arrivé au bout (ou « Terminer ») : il passe à terminé, ce qui rend la veille et le glissement, et le
    /// téléphone vibre.
    private func timerDidEnd() {
        timer.finish()
        PulseHaptics.restEnded()
    }

    private static var notRecordedNote: String {
        String(localized: "Rien n'est enregistré : la mobilité ne compte ni dans la charge ni dans ta série.", bundle: .module)
    }

    // MARK: - Minuteur

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timer.remaining(at: context.date)
            let isOver = timer.isOver(at: context.date)
            ObsidianCard {
                VStack(spacing: 14) {
                    Text(MobilityTimer.clockText(remaining))
                        .font(PulseFont.score(size: digitSize * 1.3))
                        .foregroundStyle(PulsePalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel(Self.spokenText(remaining))
                        // Le décompte change chaque seconde : VoiceOver ne le relit pas de lui-même.
                        .accessibilityAddTraits(.updatesFrequently)
                    if isOver {
                        Text(String(localized: "Mobilité terminée", bundle: .module))
                            .font(.headline)
                            .foregroundStyle(PulsePalette.text2)
                    } else {
                        controls
                    }
                }
                .frame(maxWidth: .infinity)
            }
            // Le minuteur arrive à zéro (ou « Terminer ») sous le focus : on le dit.
            .pulseAnnounce(Self.finishedAnnouncement(isOver: isOver))
            .onChange(of: isOver) { _, over in
                if over { timerDidEnd() }
            }
        }
    }

    /// « Mobilité terminée » quand le minuteur est arrivé au bout ; `nil` tant qu'il tourne.
    nonisolated static func finishedAnnouncement(isOver: Bool) -> String? {
        isOver ? String(localized: "Mobilité terminée", bundle: .module) : nil
    }

    @ViewBuilder
    private var controls: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            switch timer.phase {
            case .ready:
                Button(String(localized: "Démarrer", bundle: .module)) { timer.start(at: .now) }
                    .buttonStyle(PrimaryButtonStyle())
            case .running:
                Button(String(localized: "Pause", bundle: .module)) { timer.pause(at: .now) }
                    .buttonStyle(PrimaryButtonStyle())
                finishButton
            case .paused:
                Button(String(localized: "Reprendre", bundle: .module)) { timer.start(at: .now) }
                    .buttonStyle(PrimaryButtonStyle())
                finishButton
            case .finished:
                EmptyView()
            }
        }
    }

    private var finishButton: some View {
        Button(String(localized: "Terminer", bundle: .module)) { timer.finish() }
            .buttonStyle(SecondaryButtonStyle())
    }

    /// « Temps restant 18 minutes 55 », « Temps restant 1 minute », « Temps restant 45 secondes » : la durée dite par
    /// `PulseSpoken`, au singulier jusqu'à 1.
    static func spokenText(_ remaining: TimeInterval) -> String {
        let duration = PulseSpoken.duration(seconds: Int(max(0, remaining).rounded(.up)))
        return String(localized: "Temps restant \(duration)", bundle: .module)
    }

    // MARK: - Consignes

    private var guide: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(MobilityGuide.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(PulsePalette.muted)
                            .frame(minWidth: 18)
                            .accessibilityHidden(true)
                        Text(step)
                            .font(.body)
                            .foregroundStyle(PulsePalette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview("Mobilité") {
    MobilitySheet()
}

#Preview("Mobilité, accessibilité 3") {
    MobilitySheet()
        .dynamicTypeSize(.accessibility3)
}
