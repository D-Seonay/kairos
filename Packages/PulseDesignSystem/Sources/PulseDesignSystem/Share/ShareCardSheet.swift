import PulseDomain
import SwiftUI

/// Le bouton « Partager » d'un récap ou d'un détail : il ouvre la feuille de la carte. Le libellé est un `Label` : une icône
/// seule dans une barre d'outils, l'icône et le texte ailleurs (avec `.labelStyle(.titleAndIcon)`). Rien tant que `content`
/// est `nil` (le bilan n'est pas encore lu).
public struct ShareCardButton: View {
    private let content: ShareCardContent?
    @State private var isPresented = false

    public init(content: ShareCardContent?) {
        self.content = content
    }

    public var body: some View {
        if let content {
            Button {
                PulseHaptics.selection()
                isPresented = true
            } label: {
                Label(String(localized: "Partager", bundle: .module), systemImage: "square.and.arrow.up")
            }
            .accessibilityHint(String(localized: "Prépare une image à partager sur les réseaux", bundle: .module))
            .accessibilityIdentifier(ShareCardIdentifiers.button)
            .sheet(isPresented: $isPresented) {
                ShareCardSheet(content: content)
            }
        }
    }
}

/// La feuille de partage : l'aperçu de l'image telle qu'elle partira, le choix du format (story ou publication) et
/// « Partager », qui ouvre la feuille du système avec l'image et le texte (Instagram, WhatsApp, Snapchat, Messages, Photos…).
public struct ShareCardSheet: View {
    private let content: ShareCardContent
    @State private var format: ShareCardFormat = .story
    @State private var rendered: [ShareCardFormat: RenderedCard] = [:]
    @State private var failed = false
    @Environment(\.pulseTheme) private var theme
    @Environment(\.muscleMapFigure) private var figure
    @Environment(\.dismiss) private var dismiss

    public init(content: ShareCardContent) {
        self.content = content
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker(String(localized: "Format", bundle: .module), selection: $format) {
                    ForEach(ShareCardFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(ShareCardIdentifiers.format)

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                shareButton
            }
            .padding(PulseMetrics.spacing)
            .pulseScreenBackground()
            .navigationTitle(String(localized: "Partager", bundle: .module))
            .pulseInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Fermer", bundle: .module)) { dismiss() }
                }
            }
        }
        .task(id: format) { render(format) }
    }

    @ViewBuilder
    private var preview: some View {
        if let card = rendered[format] {
            Image(decorative: card.cgImage, scale: ShareCardFormat.scale)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous).strokeBorder(PulsePalette.line)
                }
                .shadow(color: PulsePalette.cardShadow, radius: 16, y: 6)
                .accessibilityElement()
                .accessibilityLabel(String(localized: "Aperçu de l'image", bundle: .module))
                .accessibilityValue(content.caption)
                .accessibilityAddTraits(.isImage)
                .transition(.opacity)
        } else if failed {
            Text(String(localized: "Pulse n'a pas pu préparer l'image.", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.signal)
        } else {
            ProgressView()
                .accessibilityLabel(String(localized: "Préparation de l'image", bundle: .module))
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let card = rendered[format] {
            ShareLink(item: card.image, subject: Text(content.title), message: Text(content.caption),
                      preview: SharePreview(content.title, image: Image(decorative: card.cgImage, scale: ShareCardFormat.scale))) {
                Label(String(localized: "Partager", bundle: .module), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(ShareCardIdentifiers.share)
        } else {
            Button {} label: {
                Label(String(localized: "Partager", bundle: .module), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(true)
        }
    }

    /// Tire l'image du format la première fois qu'il s'affiche, puis la garde.
    private func render(_ format: ShareCardFormat) {
        guard rendered[format] == nil else { return }
        guard let cgImage = ShareCardRenderer.cgImage(content: content, format: format, theme: theme, figure: figure),
              let png = ShareCardRenderer.png(cgImage) else {
            failed = true
            return
        }
        failed = false
        rendered[format] = RenderedCard(cgImage: cgImage, image: ShareCardImage(png: png, fileName: content.fileName))
    }
}

private struct RenderedCard {
    let cgImage: CGImage
    let image: ShareCardImage
}

/// Les identifiants d'accessibilité du partage, pour les tests d'interface.
public enum ShareCardIdentifiers {
    public static let button = "share.card.button"
    public static let format = "share.card.format"
    public static let share = "share.card.share"
}

#if DEBUG
#Preview("Feuille, séance") {
    ShareCardSheet(content: .previewSession)
}
#endif
