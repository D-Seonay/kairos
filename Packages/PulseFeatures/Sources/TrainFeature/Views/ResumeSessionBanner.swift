import PulseDesignSystem
import SwiftUI

/// Le haut de l'onglet pendant une séance : son titre, depuis quand elle dure et « Reprendre la séance ».
struct ResumeSessionBanner: View {
    let title: String
    let startedAt: Date?
    let onResume: () -> Void

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Séance en cours", bundle: .module))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PulsePalette.text2)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                    if let startedAt {
                        // `Text(_:style: .timer)` compte le temps écoulé sans que l'écran ne relise l'horloge.
                        Text(startedAt, style: .timer)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(PulsePalette.text2)
                    }
                }
                .accessibilityElement(children: .combine)
                Button(String(localized: "Reprendre la séance", bundle: .module), action: onResume)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier(TrainIdentifiers.resumeSession)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
