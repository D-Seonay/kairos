import PulseDesignSystem
import SwiftUI

/// La séance du jour est faite : son bilan (durée, séries, tonnage, records) à la place de « Démarrer ».
struct DoneSessionCard: View {
    let card: DoneCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionCardHeader(title: card.title)
            VStack(alignment: .leading, spacing: 4) {
                Label(String(localized: "Séance faite", bundle: .module), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.ok)
                Text(card.statsText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PulsePalette.text)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(TodayIdentifiers.sessionDone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Une séance est en cours : « Reprendre la séance » rouvre l'écran en direct.
struct ResumeSessionCard: View {
    let title: String
    let onResume: () -> Void

    var body: some View {
        SessionCardHeader(title: title)
        Text(String(localized: "Séance en cours", bundle: .module))
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text2)
        Button(String(localized: "Reprendre la séance", bundle: .module), action: onResume)
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(TodayIdentifiers.sessionResume)
    }
}
