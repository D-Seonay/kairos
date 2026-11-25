import PulseDomain
import SwiftUI

/// Le bouton « Partager » d'un récap ou d'un détail : il ouvre la feuille de la carte. Le libellé est un `Label` : une icône
/// seule dans une barre d'outils, l'icône et le texte ailleurs (avec `.labelStyle(.titleAndIcon)`). Rien tant que `content`
/// est `nil` (le bilan n'est pas encore lu). `photos` : les photos de la séance, proposées en fond de carte.
public struct ShareCardButton: View {
    private let content: ShareCardContent?
    private let photos: [ShareCardPhoto]
    @State private var isPresented = false

    public init(content: ShareCardContent?, photos: [ShareCardPhoto] = []) {
        self.content = content
        self.photos = photos
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
                ShareCardSheet(content: content, photos: photos)
            }
        }
    }
}

public extension View {
    /// Ouvre la feuille de partage de `content` dès qu'il n'est plus `nil`, et le remet à `nil` à la fermeture : pour un partage
    /// lancé d'un menu contextuel (un record de la liste).
    func shareCardSheet(content: Binding<ShareCardContent?>) -> some View {
        sheet(isPresented: Binding(get: { content.wrappedValue != nil }, set: { if !$0 { content.wrappedValue = nil } })) {
            if let card = content.wrappedValue {
                ShareCardSheet(content: card)
            }
        }
    }
}

/// La feuille de partage : l'aperçu de l'image telle qu'elle partira, le format (story ou publication), le fond (la trame ou
/// une photo de la séance) et « Partager », qui ouvre la feuille du système avec l'image et le texte (Instagram, WhatsApp,
/// Snapchat, Messages, Photos…).
public struct ShareCardSheet: View {
    private let content: ShareCardContent
    private let photos: [ShareCardPhoto]
    @State private var format: ShareCardFormat = .story
    @State private var background: ShareCardBackground = .pattern
    @State private var rendered: [RenderKey: RenderedCard] = [:]
    @State private var loadedPhotos: [UUID: CGImage] = [:]
    @State private var failed = false
    @Environment(\.pulseTheme) private var theme
    @Environment(\.muscleMapFigure) private var figure
    @Environment(\.dismiss) private var dismiss

    public init(content: ShareCardContent, photos: [ShareCardPhoto] = []) {
        self.content = content
        self.photos = photos
    }

    private var key: RenderKey { RenderKey(format: format, background: background) }

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

                if !photos.isEmpty {
                    ShareBackgroundPicker(photos: photos, selection: $background)
                }

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
        .task(id: key) { await render(key) }
    }

    @ViewBuilder
    private var preview: some View {
        if let card = rendered[key] {
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
        if let card = rendered[key] {
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

    /// Tire l'image du format et du fond la première fois qu'ils s'affichent, puis la garde. Une photo est lue et décodée hors de
    /// l'acteur principal.
    private func render(_ key: RenderKey) async {
        guard rendered[key] == nil else { return }
        failed = false
        var photo: CGImage?
        if case .photo(let id) = key.background {
            photo = await loadPhoto(id)
            guard photo != nil else {
                failed = true
                return
            }
        }
        guard let cgImage = ShareCardRenderer.cgImage(content: content, format: key.format, photo: photo, theme: theme,
                                                      figure: figure),
              let png = ShareCardRenderer.png(cgImage) else {
            failed = true
            return
        }
        rendered[key] = RenderedCard(cgImage: cgImage, image: ShareCardImage(png: png, fileName: content.fileName))
    }

    private func loadPhoto(_ id: UUID) async -> CGImage? {
        if let cached = loadedPhotos[id] { return cached }
        guard let source = photos.first(where: { $0.id == id }) else { return nil }
        let decoded = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let data = await source.load() else { return nil }
            return ShareCardRenderer.photo(from: data)
        }.value
        if let decoded { loadedPhotos[id] = decoded }
        return decoded
    }
}

/// Le fond de la carte : la trame Pulse, ou une photo de la séance.
enum ShareCardBackground: Hashable {
    case pattern
    case photo(UUID)
}

private struct RenderKey: Hashable {
    let format: ShareCardFormat
    let background: ShareCardBackground
}

private struct RenderedCard {
    let cgImage: CGImage
    let image: ShareCardImage
}

/// La rangée des fonds : la trame, puis une vignette par photo. Le fond choisi est cerné d'encre.
private struct ShareBackgroundPicker: View {
    let photos: [ShareCardPhoto]
    @Binding var selection: ShareCardBackground

    private static let side: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Fond", bundle: .module))
                .pulseEyebrow()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    tile(.pattern, label: String(localized: "Trame Pulse", bundle: .module)) {
                        ZStack {
                            Color(PulsePalette.pageRGBA)
                            HalftoneField(spacing: 4, color: .white.opacity(0.5)) { point in
                                Halftone.glow(at: point, center: CGPoint(x: 0.7, y: 0.3), spread: 0.45)
                            }
                        }
                    }
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        tile(.photo(photo.id), label: String(localized: "Photo \(index + 1)", bundle: .module)) {
                            if let image = ShareCardRenderer.photo(from: photo.thumbnail, maxPixelSize: 200) {
                                Image(decorative: image, scale: 1).resizable().scaledToFill()
                            } else {
                                PulsePalette.surface2
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(_ background: ShareCardBackground, label: String, @ViewBuilder content: () -> some View) -> some View {
        let isSelected = selection == background
        return Button {
            PulseHaptics.selection()
            selection = background
        } label: {
            content()
                .frame(width: Self.side, height: Self.side)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? PulsePalette.ink : PulsePalette.line, lineWidth: isSelected ? 2.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
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
