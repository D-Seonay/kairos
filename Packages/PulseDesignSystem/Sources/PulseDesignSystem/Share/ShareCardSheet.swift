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

/// La feuille de partage : l'aperçu de l'image telle qu'elle partira, le format (story ou publication), le fond (la trame, une
/// photo de la séance, ou rien) et « Partager », qui ouvre la feuille du système avec l'image et le texte (Instagram, WhatsApp,
/// Snapchat, Messages, Photos…). Sans fond, « Copier » met l'image dans le presse-papiers, à coller en sticker dans une story.
public struct ShareCardSheet: View {
    private let content: ShareCardContent
    private let photos: [ShareCardPhoto]
    @State private var format: ShareCardFormat = .story
    @State private var background: ShareCardBackground = .pattern
    @State private var rendered: [RenderKey: RenderedCard] = [:]
    @State private var loadedPhotos: [UUID: CGImage] = [:]
    @State private var failed = false
    @State private var copiedAt: Date?
    @Environment(\.pulseTheme) private var theme
    @Environment(\.muscleMapFigure) private var figure
    @Environment(\.dismiss) private var dismiss

    public init(content: ShareCardContent, photos: [ShareCardPhoto] = []) {
        self.content = content
        self.photos = photos
    }

    private var key: RenderKey { RenderKey(format: format, background: background) }
    private var isSticker: Bool { background == .transparent }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Sans fond, l'image prend la hauteur de son contenu : le format n'a plus de sens.
                if !isSticker {
                    Picker(String(localized: "Format", bundle: .module), selection: $format) {
                        ForEach(ShareCardFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(ShareCardIdentifiers.format)
                }

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ShareBackgroundPicker(photos: photos, selection: $background)

                buttons
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
                .background { if isSticker { ShareCheckerboard() } }
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

    private var buttons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if isSticker { copyButton }
                shareButton
            }
            if isSticker {
                Text(copiedAt == nil ? String(localized: "Copie l'image, puis colle-la sur ta photo dans ta story.",
                                              bundle: .module)
                                     : ShareCardSheet.copiedMessage)
                    .font(.footnote)
                    .foregroundStyle(copiedAt == nil ? PulsePalette.muted : PulsePalette.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    static var copiedMessage: String { String(localized: "Copiée, colle-la dans ta story.", bundle: .module) }

    private var copyButton: some View {
        Button {
            guard let card = rendered[key] else { return }
            ShareCardPasteboard.copy(png: card.image.png)
            PulseHaptics.success()
            PulseAnnouncement.post(Self.copiedMessage)
            let now = Date()
            copiedAt = now
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if copiedAt == now { copiedAt = nil }
            }
        } label: {
            Label(String(localized: "Copier", bundle: .module), systemImage: "doc.on.doc")
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(rendered[key] == nil)
        .accessibilityHint(String(localized: "Met l'image sans fond dans le presse-papiers, à coller dans une story",
                                  bundle: .module))
        .accessibilityIdentifier(ShareCardIdentifiers.copy)
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
        if key.background == .transparent {
            guard let cgImage = ShareCardRenderer.stickerImage(content: content, theme: theme, figure: figure),
                  let png = ShareCardRenderer.png(cgImage) else {
                failed = true
                return
            }
            rendered[key] = RenderedCard(cgImage: cgImage, image: ShareCardImage(png: png, fileName: content.stickerFileName))
            return
        }
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

/// Le fond de la carte : la trame Pulse, une photo de la séance, ou rien (l'image sans fond, un sticker).
enum ShareCardBackground: Hashable {
    case pattern
    case photo(UUID)
    case transparent
}

/// Une image tirée : son format et son fond. Sans fond, le format ne compte pas (l'image prend la hauteur de son contenu) :
/// passer de Story à Publication ne la tire pas une seconde fois.
struct RenderKey: Hashable {
    let format: ShareCardFormat
    let background: ShareCardBackground

    init(format: ShareCardFormat, background: ShareCardBackground) {
        self.format = background == .transparent ? .story : format
        self.background = background
    }
}

/// Le damier derrière l'aperçu de l'image sans fond : ce qui est transparent se voit. Deux gris moyens fixes, pour que l'encre
/// blanche ressorte dans les deux apparences.
struct ShareCheckerboard: View {
    var side: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.42)))
            var squares = Path()
            let columns = Int((size.width / side).rounded(.up)), rows = Int((size.height / side).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    squares.addRect(CGRect(x: CGFloat(column) * side, y: CGFloat(row) * side, width: side, height: side))
                }
            }
            context.fill(squares, with: .color(Color(white: 0.52)))
        }
        .accessibilityHidden(true)
    }
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
                    tile(.transparent, label: String(localized: "Sans fond", bundle: .module)) {
                        ShareCheckerboard(side: 7)
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
    public static let copy = "share.card.copy"
}

#if DEBUG
#Preview("Feuille, séance") {
    ShareCardSheet(content: .previewSession)
}
#endif
