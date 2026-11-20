import CoreGraphics
import Testing

@testable import PulseDesignSystem

@Test func fullLightDrawsEveryDotOfTheGrid() {
    let path = Halftone.dots(in: CGSize(width: 40, height: 40), spacing: 10, maxRadius: 4) { _ in 1 }
    #expect(!path.isEmpty)
    #expect(path.boundingRect.minX >= 0 && path.boundingRect.maxX <= 40)
}

@Test func noLightDrawsNothing() {
    #expect(Halftone.dots(in: CGSize(width: 40, height: 40), spacing: 10, maxRadius: 4) { _ in 0 }.isEmpty)
}

@Test func emptyOrInvalidGridDrawsNothing() {
    #expect(Halftone.dots(in: .zero, spacing: 10, maxRadius: 4) { _ in 1 }.isEmpty)
    #expect(Halftone.dots(in: CGSize(width: 40, height: 40), spacing: 0, maxRadius: 4) { _ in 1 }.isEmpty)
}

@Test func lightIsClampedToTheMaximumRadius() {
    let bright = Halftone.dots(in: CGSize(width: 10, height: 10), spacing: 10, maxRadius: 2) { _ in 5 }
    let full = Halftone.dots(in: CGSize(width: 10, height: 10), spacing: 10, maxRadius: 2) { _ in 1 }
    #expect(bright.boundingRect == full.boundingRect)
}

@Test func glowIsFullAtItsCenterAndFadesAway() {
    let center = CGPoint(x: 0.5, y: 0.5)
    #expect(Halftone.glow(at: center, center: center, spread: 0.3) == 1)
    #expect(Halftone.glow(at: CGPoint(x: 1, y: 1), center: center, spread: 0.3) < 0.3)
}
