import CoreGraphics
import CoreTransferable
import Foundation
import ImageIO
import PulseDomain
import SwiftUI
import UniformTypeIdentifiers

/// L'image partagée : le PNG de la carte et le nom de son fichier. Les apps de la feuille de partage (Instagram, WhatsApp,
/// Photos…) la reçoivent comme une image.
public struct ShareCardImage: Transferable, Sendable {
    public let png: Data
    public let fileName: String

    public init(png: Data, fileName: String) {
        self.png = png
        self.fileName = fileName
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
            .suggestedFileName { $0.fileName }
    }
}

/// Tire la carte en image, à 1 080 pixels de large. La carte se dessine hors de l'écran : le thème et la silhouette du profil
/// sont passés à la main, l'environnement de l'écran ne la suit pas.
@MainActor
public enum ShareCardRenderer {
    public static func cgImage(content: ShareCardContent, format: ShareCardFormat, theme: Theme = .amber,
                               figure: MuscleMapFigure = .female) -> CGImage? {
        let card = ShareCardView(content: content, format: format)
            .environment(\.pulseTheme, theme)
            .environment(\.muscleMapFigure, figure)
        let renderer = ImageRenderer(content: card)
        renderer.scale = ShareCardFormat.scale
        renderer.proposedSize = ProposedViewSize(format.size)
        renderer.isOpaque = true
        return renderer.cgImage
    }

    /// Le PNG de `image` ; `nil` si ImageIO ne sait pas l'écrire.
    public static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
