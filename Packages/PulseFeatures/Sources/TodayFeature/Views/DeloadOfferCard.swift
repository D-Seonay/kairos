import PulseDesignSystem
import PulseServices
import SwiftUI

/// La proposition d'une semaine de décharge (spec M6 §10) : le ratio qui reste haut, ce que la décharge change, et deux choix.
struct DeloadOfferCard: View {
    let offer: DeloadOffer
    /// L'échec de l'enregistrement du choix, juste au-dessus des boutons.
    var errorMessage: String?
    let onDecide: (Bool) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Semaine de décharge", bundle: .module))
                    .pulseEyebrow(PulsePalette.text2)
                    .accessibilityAddTraits(.isHeader)
                Text(Self.message(offer))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
                buttons
            }
        }
        .accessibilityIdentifier(TodayIdentifiers.deloadOffer)
        // Le message apparaît sous le focus, sur la carte qui reste là : l'annonce suit son changement.
        .pulseAnnounceError(errorMessage)
    }

    /// « Ta charge reste haute : ratio 1,62 deux jours de suite. … »
    static func message(_ offer: DeloadOffer) -> String {
        let ratio = PulseFormat.decimal(offer.ratio, maxFractionDigits: 2)
        return String(localized: """
            Ta charge reste haute : ratio \(ratio) deux jours de suite. Jusqu'à dimanche, 40 % de séries en moins et des charges \
            10 % plus basses laissent ton corps encaisser.
            """, bundle: .module)
    }

    /// Côte à côte, empilés aux tailles d'accessibilité.
    private var buttons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button(String(localized: "Commencer la décharge", bundle: .module)) { onDecide(true) }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier(TodayIdentifiers.deloadAccept)
            Button(String(localized: "Pas cette fois", bundle: .module)) { onDecide(false) }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier(TodayIdentifiers.deloadDecline)
        }
    }
}
