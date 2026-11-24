#if DEBUG
import CoreGraphics
import ImageIO
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import UniformTypeIdentifiers

/// Des photos de séance pour les aperçus : un dépôt en mémoire garni d'images unies fabriquées à la volée.
@MainActor
enum PhotosPreviewSupport {
    /// Un modèle vide, sur un dépôt en mémoire.
    static func emptyModel() -> SessionPhotosModel {
        let service = SessionPhotoService(repository: InMemorySessionPhotoRepository(), timeZone: .current, now: { Date() })
        return SessionPhotosModel(service: service, sessionID: UUID(), calendar: .current)
    }

    /// Un modèle qui se garnit de `count` photos dès qu'il existe.
    static func model(count: Int) -> SessionPhotosModel {
        let model = emptyModel()
        Task { await seed(model, count: count) }
        return model
    }

    static func seed(_ model: SessionPhotosModel, count: Int) async {
        await model.add((0..<count).map { jpeg(hue: Double($0) / 6) })
    }

    /// Un JPEG uni de 120 × 90 pixels.
    static func jpeg(hue: Double) -> Data {
        guard let context = CGContext(data: nil, width: 120, height: 90, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return Data() }
        context.setFillColor(CGColor(red: 0.3 + 0.4 * hue, green: 0.5, blue: 0.7 - 0.4 * hue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 90))
        let output = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}

/// Garde le modèle de l'aperçu en `@State` : il ne survit pas à un corps recalculé.
struct PhotosPreviewHost<Content: View>: View {
    @State private var model: SessionPhotosModel
    private let content: (SessionPhotosModel) -> Content

    init(count: Int, @ViewBuilder content: @escaping (SessionPhotosModel) -> Content) {
        _model = State(initialValue: PhotosPreviewSupport.model(count: count))
        self.content = content
    }

    var body: some View {
        content(model).background(PulsePalette.background)
    }
}
#endif
