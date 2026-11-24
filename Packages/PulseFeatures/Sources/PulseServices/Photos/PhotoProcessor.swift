import CoreGraphics
import Foundation
import ImageIO
import PulseDomain
import UniformTypeIdentifiers

/// Une photo prête à être stockée : image et vignette sans métadonnées, plus la date de prise de vue lue avant le nettoyage.
public struct ProcessedPhoto: Sendable, Equatable {
    public var image: PhotoImage
    public var capturedAt: Date?

    public init(image: PhotoImage, capturedAt: Date?) {
        self.image = image
        self.capturedAt = capturedAt
    }
}

public enum PhotoProcessingError: Error, Equatable {
    /// Les données ne sont pas une image que ImageIO sait lire.
    case unreadable
    /// L'image a été lue, mais son réencodage en JPEG a échoué.
    case encodingFailed
}

/// Traite toute photo avant stockage : redressée selon l'orientation EXIF, réduite, réencodée en JPEG **sans aucune métadonnée**
/// (ni GPS, ni EXIF, ni TIFF). Les propriétés de la source ne sont jamais recopiées vers la sortie.
public enum PhotoProcessor {
    public static let longSide = 2048
    public static let thumbnailLongSide = 400
    public static let quality = 0.8

    /// Redresse selon l'orientation EXIF, réduit, réencode en JPEG sans aucune métadonnée. `capturedAt` vient de
    /// `DateTimeOriginal`, lu dans `timeZone` (l'EXIF n'a pas de fuseau).
    public static func process(_ data: Data, timeZone: TimeZone) throws -> ProcessedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw PhotoProcessingError.unreadable
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let full = try encodedJPEG(from: source, longSide: longSide, properties: properties)
        let thumbnail = try encodedJPEG(from: source, longSide: thumbnailLongSide, properties: properties)
        return ProcessedPhoto(image: PhotoImage(image: full, thumbnail: thumbnail),
                              capturedAt: captureDate(in: properties, timeZone: timeZone))
    }

    /// Redresse et réduit l'image au grand côté demandé (sans jamais agrandir), puis l'encode en JPEG.
    private static func encodedJPEG(from source: CGImageSource, longSide: Int, properties: [CFString: Any]?) throws -> Data {
        // `kCGImageSourceThumbnailMaxPixelSize` agrandirait une petite image : on plafonne au grand côté d'origine.
        let width = (properties?[kCGImagePropertyPixelWidth] as? Int) ?? longSide
        let height = (properties?[kCGImagePropertyPixelHeight] as? Int) ?? longSide
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(longSide, max(width, height))
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoProcessingError.unreadable
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoProcessingError.encodingFailed
        }
        // Seule la qualité est fournie : aucune propriété de la source n'est recopiée.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoProcessingError.encodingFailed }
        return output as Data
    }

    /// `DateTimeOriginal` est écrit « 2026:08:01 07:30:00 », sans fuseau : on le lit dans celui de l'appelant.
    private static func captureDate(in properties: [CFString: Any]?, timeZone: TimeZone) -> Date? {
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        guard let text = exif?[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }
}
