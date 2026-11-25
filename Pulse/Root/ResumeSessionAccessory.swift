import LiveSessionFeature
import PulseDesignSystem
import SwiftUI

/// « Reprendre la séance » dans l'accessoire de la barre d'onglets (iOS 26.1), quand une séance est en cours sans être à l'écran.
/// Déplié au-dessus de la barre : l'haltère, le titre, la durée écoulée, « Reprendre » et la croix « Abandonner ». Replié dans la
/// barre réduite par le défilement : l'haltère, le titre et la durée, qui reprennent la séance au toucher ; « Abandonner » reste
/// dans le menu contextuel et dans les actions de VoiceOver. L'abandon se confirme dans les onglets, comme depuis le bandeau.
struct ResumeSessionAccessory: View {
    let title: String
    let startedAt: Date
    let onResume: () -> Void
    /// Demande l'abandon : les onglets le confirment avant d'abandonner.
    let onAbandon: () -> Void
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isInline: Bool { placement == .inline }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onResume) {
                resumeLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Reprendre la séance"))
            .accessibilityValue(title)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier(ResumeSessionBar.resumeIdentifier)
            .accessibilityAction(named: Text(String(localized: "Abandonner la séance")), onAbandon)
            if !isInline {
                Button(action: onAbandon) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulsePalette.text2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Abandonner la séance"))
                .accessibilityIdentifier(LiveSessionIdentifiers.abandonBannerButton)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, isInline ? 16 : 4)
        // L'accessoire a la hauteur fixe de la barre d'onglets : le texte s'y arrête aux grandes tailles, sur une ligne.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .contextMenu {
            Button(String(localized: "Abandonner la séance"), systemImage: "xmark", role: .destructive, action: onAbandon)
        }
        .accessibilityIdentifier(LiveSessionIdentifiers.resumeBanner)
    }

    private var resumeLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.subheadline)
                .foregroundStyle(PulsePalette.signal)
            if isInline {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                timer
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(String(localized: "Séance en cours"))
                        Text(verbatim: "·")
                        timer
                    }
                    .font(.caption)
                    .foregroundStyle(PulsePalette.text2)
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(String(localized: "Reprendre"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulsePalette.signal)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// `Text(_:style: .timer)` compte le temps écoulé sans que la vue ne relise l'horloge ; `fixedSize` le garde entier quand le
    /// titre se coupe.
    private var timer: some View {
        Text(startedAt, style: .timer)
            .font(.caption.monospacedDigit())
            .foregroundStyle(PulsePalette.text2)
            .fixedSize()
    }
}

#if DEBUG
#Preview("Accessoire « Reprendre la séance »") {
    TabView {
        Tab("Aujourd'hui", systemImage: "sun.max") {
            Color.clear
        }
        Tab("Séance", systemImage: "dumbbell") {
            Color.clear
        }
    }
    .tabViewBottomAccessory {
        ResumeSessionAccessory(title: "Push", startedAt: Date(timeIntervalSinceNow: -1_800), onResume: {}, onAbandon: {})
    }
}
#endif
