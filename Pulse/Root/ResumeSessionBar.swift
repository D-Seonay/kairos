import LiveSessionFeature
import PulseDesignSystem
import SwiftUI

/// Le bandeau « Reprendre la séance » en haut des onglets, quand une séance est en cours sans être à l'écran (après une relance) :
/// son titre, la durée écoulée depuis `startedAt`, « Reprendre » et « Abandonner », confirmé, qui garde les séries validées
/// (spec M4 §16).
struct ResumeSessionBar: View {
    /// Ce que le test d'interface touche pour reprendre la séance après un arrêt forcé.
    static let resumeIdentifier = "session.resume"

    let title: String
    let startedAt: Date
    let onResume: () -> Void
    let onAbandon: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmsAbandon = false

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Séance en cours"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PulsePalette.text2)
                    Text(title)
                        .font(.headline)
                    // `Text(_:style: .timer)` compte le temps écoulé sans que l'écran ne relise l'horloge.
                    Text(startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(PulsePalette.text2)
                }
                .accessibilityElement(children: .combine)
                buttons
            }
        }
        .accessibilityIdentifier(LiveSessionIdentifiers.resumeBanner)
        .confirmationDialog(String(localized: "Abandonner la séance ?"), isPresented: $confirmsAbandon,
                            titleVisibility: .visible) {
            Button(String(localized: "Abandonner"), role: .destructive, action: onAbandon)
            Button(String(localized: "Continuer la séance"), role: .cancel) {}
        } message: {
            Text(String(localized: "Les séries validées sont gardées, les autres ne sont pas enregistrées."))
        }
    }

    /// Côte à côte, l'un sous l'autre aux tailles de texte d'accessibilité.
    private var buttons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button(String(localized: "Reprendre"), action: onResume)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(String(localized: "Reprendre la séance"))
                .accessibilityIdentifier(Self.resumeIdentifier)
            Button(String(localized: "Abandonner")) { confirmsAbandon = true }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel(String(localized: "Abandonner la séance"))
                .accessibilityIdentifier(LiveSessionIdentifiers.abandonBannerButton)
        }
    }
}
