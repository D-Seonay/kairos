import PulseDesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Image {
    /// L'image décodée depuis des octets (JPEG) ; `nil` si les octets ne sont pas une image.
    init?(photoData data: Data) {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
        #else
        return nil
        #endif
    }
}

/// Une vignette carrée : l'image remplit la case, rognée au centre ; sans image, un fond neutre.
struct PhotoSquare: View {
    let data: Data?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let data, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    PulsePalette.surface2
                        .overlay { Image(systemName: "photo").foregroundStyle(PulsePalette.muted) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
                    .strokeBorder(PulsePalette.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
    }
}

private struct PhotoAnnouncements: ViewModifier {
    let model: SessionPhotosModel

    func body(content: Content) -> some View {
        content
            // Le compteur change à chaque annonce : deux « Photo ajoutée » de suite se disent deux fois.
            .onChange(of: model.announcementSerial) {
                if let text = model.announcement { PulseAnnouncement.post(text) }
            }
            .pulseAnnounceError(model.errorMessage)
    }
}

extension View {
    /// Poste les annonces du modèle (« Photo ajoutée », « Photo supprimée ») et ses erreurs. À poser une fois par écran : la
    /// section Photos ou le bouton de la séance live, pas les deux.
    func photoAnnouncements(_ model: SessionPhotosModel) -> some View {
        modifier(PhotoAnnouncements(model: model))
    }

    /// La visionneuse plein écran (une feuille sur Mac, où le plein écran n'existe pas).
    @ViewBuilder
    func photoViewerCover<Item: Identifiable>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> some View) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }
}
