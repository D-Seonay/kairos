import PulseDesignSystem
import SwiftUI

/// Quand le stockage n'a pas pu être ouvert ou lu : l'app le dit, au lieu de montrer l'onboarding sur un magasin vide, qui
/// ferait croire que tout est perdu. « Réessayer » n'existe que si relire peut suffire ; sinon seule une relance de l'app
/// rouvre le stockage.
struct StorageUnavailableView: View {
    static let contactEmail = "contact@seonay.com"

    let canRetry: Bool
    let retry: () async -> Void
    @State private var isRetrying = false

    var body: some View {
        ZStack {
            PulsePalette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(PulsePalette.text2)
                        .accessibilityHidden(true)
                    Text(String(localized: "Pulse n'arrive pas à ouvrir tes données"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(String(localized: """
                    Pulse n'a rien effacé. Tes séances, ton programme et tes réglages ne s'affichent pas tant que le stockage \
                    ne répond pas, pour que rien ne soit écrasé.
                    """))
                    Text(Self.advice(canRetry: canRetry))
                    actions
                }
                .font(.body)
                .foregroundStyle(PulsePalette.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            if canRetry {
                Button(String(localized: "Réessayer")) {
                    guard !isRetrying else { return }
                    isRetrying = true
                    Task {
                        await retry()
                        isRetrying = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRetrying)
            }
            if let url = Self.contactURL {
                Link(String(localized: "Écrire à \(Self.contactEmail)"), destination: url)
                    .buttonStyle(LinkButtonStyle())
            }
        }
        .padding(.top, 4)
    }

    /// Ce qu'il reste à faire : relire quand c'est possible, sinon relancer l'app.
    static func advice(canRetry: Bool) -> String {
        if canRetry {
            String(localized: """
            Réessaie. Si l'écran revient, ferme complètement Pulse puis rouvre-la, libère de l'espace sur l'iPhone ou \
            redémarre-le.
            """)
        } else {
            String(localized: """
            Ferme complètement Pulse puis rouvre-la. Si l'écran revient, libère de l'espace sur l'iPhone ou redémarre-le.
            """)
        }
    }

    static var contactURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactEmail
        components.queryItems = [URLQueryItem(name: "subject", value: String(localized: "Pulse : stockage indisponible"))]
        return components.url
    }
}

#if DEBUG
#Preview("Stockage indisponible") {
    StorageUnavailableView(canRetry: false) {}
}

#Preview("Stockage indisponible, lecture à refaire, accessibilité 3") {
    StorageUnavailableView(canRetry: true) {}
        .dynamicTypeSize(.accessibility3)
}
#endif
