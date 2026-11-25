import CoreGraphics
import Foundation
import Testing

@testable import PulseDesignSystem

private func content(title: String = "Push", metrics: [ShareCardMetric] = [], visual: ShareCardContent.Visual = .none)
    -> ShareCardContent {
    ShareCardContent(eyebrow: "Séance", title: title, subtitle: "mardi 24 novembre", metrics: metrics, visual: visual)
}

@Test func captionJoinsTheTitleAndMetricsThenLinksToTheAppStore() {
    let card = content(metrics: [ShareCardMetric(value: "1 h 05", label: "Durée", caption: "1 h 05"),
                                 ShareCardMetric(value: "4 250", label: "kg soulevés", caption: "4 250 kg")])
    let lines = card.caption.components(separatedBy: "\n")
    #expect(lines.first == "Push · 1 h 05 · 4 250 kg")
    #expect(lines.last?.hasSuffix(ShareCardContent.appStoreLink) == true)
}

@Test func captionSkipsAnEmptyTitle() {
    let card = content(title: "", metrics: [ShareCardMetric(value: "12", label: "séries")])
    #expect(card.caption.hasPrefix("12 séries\n"))
}

@Test func onlyTheFirstFourMetricsAreKept() {
    let metrics = (1...6).map { ShareCardMetric(value: "\($0)", label: "x") }
    #expect(content(metrics: metrics).metrics.count == ShareCardContent.maxMetrics)
}

@Test func fileNameDropsCharactersAFileNameRefuses() {
    #expect(content(title: "Haut / Bas: A").fileName == "Pulse - Haut   Bas  A.png")
    #expect(content(title: "  ").fileName == "Pulse.png")
}

@Test func formatsAreTenEightyPixelsWide() {
    for format in ShareCardFormat.allCases {
        #expect(format.size.width * ShareCardFormat.scale == 1_080)
    }
    #expect(ShareCardFormat.story.size.height * ShareCardFormat.scale == 1_920)
    #expect(ShareCardFormat.post.size.height * ShareCardFormat.scale == 1_350)
}

@Test func routeFitsTheUnitSquareKeepingItsProportions() {
    // 1 km vers l'est, 500 m vers le nord, à Paris : le tracé est deux fois plus large que haut.
    let latitude = 48.85, metersPerDegree = 111_320.0
    let east = 1_000 / (metersPerDegree * cos(latitude * .pi / 180))
    let north = 500 / metersPerDegree
    let points = ShareRoute.normalized(latitudes: [latitude, latitude, latitude + north],
                                       longitudes: [2.35, 2.35 + east, 2.35 + east])
    #expect(points.count == 3)
    let xs = points.map(\.x), ys = points.map(\.y)
    let width = (xs.max() ?? 0) - (xs.min() ?? 0)
    let height = (ys.max() ?? 0) - (ys.min() ?? 0)
    #expect(abs(width - 1) < 0.001)
    #expect(abs(height - 0.5) < 0.01)
    // Centré verticalement, le nord en haut : l'arrivée, au nord, est plus haute que le départ.
    #expect(abs((ys.min() ?? 0) - 0.25) < 0.01)
    #expect(points[2].y < points[0].y)
}

@Test func routeIsThinnedButKeepsItsEnds() {
    let latitudes = (0..<1_000).map { 48.85 + Double($0) * 0.00001 }
    let longitudes = (0..<1_000).map { 2.35 + Double($0) * 0.00002 }
    let points = ShareRoute.normalized(latitudes: latitudes, longitudes: longitudes, maxPoints: 100)
    #expect(points.count <= 101)
    let full = ShareRoute.normalized(latitudes: latitudes, longitudes: longitudes, maxPoints: 10_000)
    #expect(points.first == full.first)
    #expect(points.last == full.last)
}

@Test func routeWithoutDistinctPointsIsEmpty() {
    #expect(ShareRoute.normalized(latitudes: [48.85], longitudes: [2.35]).isEmpty)
    #expect(ShareRoute.normalized(latitudes: [48.85, 48.85], longitudes: [2.35, 2.35]).isEmpty)
}

@Test func routeShapeIsCenteredInAWideFrame() {
    let placed = ShareRouteShape.place([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], in: CGRect(x: 0, y: 0, width: 300, height: 100))
    #expect(placed == [CGPoint(x: 100, y: 0), CGPoint(x: 200, y: 100)])
}

@MainActor
@Test func rendererDrawsAPNGAtTheFormatsPixelSize() throws {
    let card = content(metrics: [ShareCardMetric(value: "18", label: "Séries")], visual: .muscles([.chest: 4]))
    for format in ShareCardFormat.allCases {
        let image = try #require(ShareCardRenderer.cgImage(content: card, format: format))
        #expect(CGFloat(image.width) == format.size.width * ShareCardFormat.scale)
        #expect(CGFloat(image.height) == format.size.height * ShareCardFormat.scale)
        let png = try #require(ShareCardRenderer.png(image))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }
}

@Test func moreRecordsSaysOneOrMany() {
    #expect(ShareCardText.moreRecords(1) == "+ 1 autre record")
    #expect(ShareCardText.moreRecords(3) == "+ 3 autres records")
}

@Test func captionPutsARecordValueAfterTheTitle() {
    let card = ShareCardContent(eyebrow: "Record", title: "Squat", subtitle: "",
                                metrics: [ShareCardMetric(value: "+5 kg", label: "x", caption: "+5 kg")],
                                visual: .hero(value: "140 kg", label: "1RM estimé"))
    #expect(card.caption.hasPrefix("Squat · 140 kg · +5 kg\n"))
}

@Test func hypnogramBarsAreClippedToTheNightAndDropUnknownRows() {
    let start = Date(timeIntervalSince1970: 0), end = start.addingTimeInterval(1_000)
    let bars = ShareCardHypnogram.bars(
        of: [.init(row: 1, start: start.addingTimeInterval(-100), end: start.addingTimeInterval(250)),
             .init(row: nil, start: start.addingTimeInterval(250), end: start.addingTimeInterval(500)),
             .init(row: 7, start: start.addingTimeInterval(500), end: start.addingTimeInterval(600)),
             .init(row: 2, start: start.addingTimeInterval(900), end: end.addingTimeInterval(100)),
             .init(row: 0, start: end, end: end.addingTimeInterval(60))],
        from: start, to: end, rowCount: 4)
    #expect(bars == [.init(row: 1, start: 0, end: 0.25), .init(row: 2, start: 0.9, end: 1)])
    #expect(ShareCardHypnogram.bars(of: [.init(row: 0, start: start, end: end)], from: end, to: start, rowCount: 4).isEmpty)
}

@Test func deeperHypnogramRowsAreInkedMore() {
    #expect(ShareHypnogramView.opacity(row: 0, of: 4) < ShareHypnogramView.opacity(row: 3, of: 4))
    #expect(ShareHypnogramView.opacity(row: 3, of: 4) == 1)
}

@MainActor
@Test func photoIsDecodedScaledAndDrawnBehindTheCard() throws {
    let context = try #require(CGContext(data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
    let source = try #require(context.makeImage())
    let png = try #require(ShareCardRenderer.png(source))
    let photo = try #require(ShareCardRenderer.photo(from: png, maxPixelSize: 200))
    #expect(max(photo.width, photo.height) == 200)
    #expect(ShareCardRenderer.photo(from: Data("pas une image".utf8)) == nil)
    let image = try #require(ShareCardRenderer.cgImage(content: content(), format: .story, photo: photo))
    #expect(image.width == 1_080)
}

// MARK: Sticker (sans fond)

/// L'opacité du pixel (`x`, `y`) de `image`, comptée depuis le haut.
private func alpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
    var pixel: [UInt8] = [0, 0, 0, 0]
    pixel.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    }
    return pixel[3]
}

@MainActor
@Test func stickerIsTenEightyWideWithTransparentEdges() throws {
    let image = try #require(ShareCardRenderer.stickerImage(content: .previewSession))
    #expect(image.width == 1_080)
    #expect(image.height > 0 && image.height < 1_920)
    #expect(alpha(of: image, x: 0, y: 0) == 0)
    #expect(alpha(of: image, x: image.width - 1, y: image.height - 1) == 0)
    let png = try #require(ShareCardRenderer.png(image))
    #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
}

@MainActor
@Test func everyVisualRendersASticker() throws {
    for card in [ShareCardContent.previewSession, .previewRun, .previewRecord, .previewNight] {
        let image = try #require(ShareCardRenderer.stickerImage(content: card))
        #expect(image.width == 1_080)
        #expect(alpha(of: image, x: 0, y: 0) == 0)
        // De l'encre quelque part : une ligne au premier tiers traverse le titre ou les chiffres.
        let inked = (0..<image.height).contains { y in
            stride(from: 0, to: image.width, by: 8).contains { alpha(of: image, x: $0, y: y) > 0 }
        }
        #expect(inked)
    }
}

@MainActor
@Test func stickerHeightFollowsTheContent() throws {
    let small = content(metrics: [ShareCardMetric(value: "18", label: "Séries")], visual: .none)
    let tall = try #require(ShareCardRenderer.stickerImage(content: .previewSession))
    let short = try #require(ShareCardRenderer.stickerImage(content: small))
    #expect(short.height < tall.height)
}

@Test func stickerFileNameSaysSansFond() {
    #expect(ShareCardContent.previewSession.stickerFileName == "Pulse - Push (sans fond).png")
    #expect(content(title: "").stickerFileName == "Pulse (sans fond).png")
}

@Test func stickerKeyIgnoresTheFormat() {
    #expect(RenderKey(format: .story, background: .transparent) == RenderKey(format: .post, background: .transparent))
    #expect(RenderKey(format: .story, background: .pattern) != RenderKey(format: .post, background: .pattern))
}
