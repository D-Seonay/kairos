import CoreGraphics
import Foundation
import ImageIO
import PulseDomain
import PulseServices
import Testing
import UniformTypeIdentifiers

struct PhotoProcessorTests {
    private let paris = TimeZone(identifier: "Europe/Paris") ?? .gmt

    /// Fabrique un JPEG de `width` × `height` pixels avec les propriétés données (EXIF, GPS, TIFF, orientation…).
    private func makeImage(width: Int, height: Int, properties: [CFString: Any] = [:]) throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func pixelSize(_ data: Data) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }

    private func properties(_ data: Data) throws -> [String: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
    }

    @Test func downscalesLongSideTo2048() throws {
        let processed = try PhotoProcessor.process(makeImage(width: 3000, height: 1000), timeZone: paris)
        let full = try pixelSize(processed.image.image)
        let thumbnail = try pixelSize(processed.image.thumbnail)
        #expect(full.width == 2048 && abs(full.height - 683) <= 1)
        #expect(thumbnail.width == 400 && abs(thumbnail.height - 133) <= 1)
    }

    @Test func keepsSmallerImagesAtTheirSize() throws {
        let processed = try PhotoProcessor.process(makeImage(width: 800, height: 600), timeZone: paris)
        let full = try pixelSize(processed.image.image)
        #expect(full.width == 800 && full.height == 600)
    }

    @Test func orientationIsAppliedToPixels() throws {
        let source = try makeImage(width: 400, height: 200, properties: [kCGImagePropertyOrientation: 6])
        let processed = try PhotoProcessor.process(source, timeZone: paris)
        let full = try pixelSize(processed.image.image)
        #expect(full.height > full.width)
        let orientation = try properties(processed.image.image)[kCGImagePropertyOrientation as String] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    @Test func processedImageHasNoMetadata() throws {
        let source = try makeImage(width: 600, height: 400, properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 48.85, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:08:01 07:30:00"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple"]
        ])
        // La source contient bien les métadonnées, sinon le test ne prouverait rien.
        #expect(try properties(source)[kCGImagePropertyGPSDictionary as String] != nil)
        let processed = try PhotoProcessor.process(source, timeZone: paris)
        for data in [processed.image.image, processed.image.thumbnail] {
            let found = try properties(data)
            #expect(found[kCGImagePropertyGPSDictionary as String] == nil)
            let exif = found[kCGImagePropertyExifDictionary as String] as? [String: Any]
            #expect(exif?[kCGImagePropertyExifDateTimeOriginal as String] == nil)
            let tiff = found[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
            #expect(tiff?[kCGImagePropertyTIFFMake as String] == nil)
        }
    }

    @Test func readsOriginalCaptureDate() throws {
        let source = try makeImage(width: 600, height: 400, properties: [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:08:01 07:30:00"]
        ])
        let processed = try PhotoProcessor.process(source, timeZone: paris)
        let expected = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC"),
                                      year: 2026, month: 8, day: 1, hour: 5, minute: 30).date
        #expect(processed.capturedAt == expected)
    }

    @Test func missingCaptureDateIsNil() throws {
        let processed = try PhotoProcessor.process(makeImage(width: 600, height: 400), timeZone: paris)
        #expect(processed.capturedAt == nil)
    }

    @Test func rejectsNonImageData() {
        #expect(throws: PhotoProcessingError.unreadable) {
            try PhotoProcessor.process(Data("abc".utf8), timeZone: paris)
        }
    }
}
