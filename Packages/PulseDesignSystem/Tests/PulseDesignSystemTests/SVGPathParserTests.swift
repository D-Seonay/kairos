import CoreGraphics
import SwiftUI
import Testing

@testable import PulseDesignSystem

@Test func absoluteSquare() throws {
    #expect(try SVGPathParser.parse("M0,0 L10,0 L10,10 L0,10 Z").boundingRect == CGRect(x: 0, y: 0, width: 10, height: 10))
}

@Test func relativeAndImplicitCommands() throws {
    #expect(try SVGPathParser.parse("m 5 5 10 0 v 10 h -10 z").boundingRect == CGRect(x: 5, y: 5, width: 10, height: 10))
}

@Test func cubicAndQuadraticStayInsideControlHull() throws {
    let rect = try SVGPathParser.parse("M0,0 C0,10 10,10 10,0 Q15,-10 20,0").boundingRect
    #expect(rect.minX >= 0 && rect.maxX <= 20 && rect.minY >= -10 && rect.maxY <= 10)
}

@Test func halfCircleArc() throws {
    let rect = try SVGPathParser.parse("M0,0 a5,5 0 0 1 10,0").boundingRect
    #expect(abs(rect.width - 10) < 0.01 && abs(rect.height - 5) < 0.05)
}

@Test func compactArcFlags() throws {
    #expect(try SVGPathParser.parse("M0,0 a5 5 0 0110 0").boundingRect.width > 9.9)
}

@Test func garbageThrows() {
    #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0,0 L10") }
    #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0,0 X5,5") }
}

@Test func errorsCarryTheirOffset() {
    #expect(throws: SVGPathError.unexpectedCharacter("X", offset: 5)) { try SVGPathParser.parse("M0,0 X5,5") }
    #expect(throws: SVGPathError.missingNumber(command: "L", offset: 8)) { try SVGPathParser.parse("M0,0 L10") }
}

@Test func firstCommandMustBeMoveTo() {
    #expect(throws: SVGPathError.unexpectedCharacter("L", offset: 0)) { try SVGPathParser.parse("L1,1") }
    #expect(throws: SVGPathError.unexpectedCharacter("1", offset: 0)) { try SVGPathParser.parse("1,1") }
}

@Test func numbersAfterCloseThrow() {
    #expect(throws: SVGPathError.self) { try SVGPathParser.parse("M0,0 L5,5 Z 3,3") }
}

@Test func emptyDataGivesAnEmptyPath() throws {
    #expect(try SVGPathParser.parse("  ").isEmpty)
}

@Test func numberFormsAreAllRead() throws {
    let rect = try SVGPathParser.parse("M-.5,.5 l1e1,0 0.35-0.5 .5.5").boundingRect
    #expect(abs(rect.minX + 0.5) < 1e-4 && abs(rect.maxX - 10.35) < 1e-4)
    #expect(abs(rect.minY - 0) < 1e-4 && abs(rect.maxY - 0.5) < 1e-4)
}

@Test func relativeMoveAfterCloseStartsFromSubpathStart() throws {
    let rect = try SVGPathParser.parse("M10,10 l5,0 l0,5 z m 20,0 l5,0").boundingRect
    #expect(rect == CGRect(x: 10, y: 10, width: 25, height: 5))
}

@Test func relativeCurvesUseTheCommandStartPoint() throws {
    let rect = try SVGPathParser.parse("M10,10 c 0,5 5,5 5,0").boundingRect
    // Le contrôle 1 est à (10, 15) et non à (0, 5) : la courbe reste dans le rectangle (10…15, 10…15).
    #expect(rect.minX >= 10 && rect.maxX <= 15 && rect.minY >= 10 && rect.maxY > 13 && rect.maxY <= 15)
}

@Test func halfCircleDependsOnlyOnTheSweepFlag() throws {
    // Corde = diamètre : les deux drapeaux « grand arc » décrivent le même demi-cercle ; seul `sweep` compte.
    // sweep 1 : centre (5, 0), l'arc passe par le point haut (5, -5).
    for large in [0, 1] {
        let up = try SVGPathParser.parse("M0,0 A5,5 0 \(large) 1 10,0").boundingRect
        #expect(abs(up.minY + 5) < 0.05 && up.maxY < 0.05)
        let down = try SVGPathParser.parse("M0,0 A5,5 0 \(large) 0 10,0").boundingRect
        #expect(abs(down.maxY - 5) < 0.05 && down.minY > -0.05)
    }
}

@Test func smallAndLargeArcsPickTheTwoDifferentCentres() throws {
    // Corde (0,0)→(10,0), r = 10 : les centres sont (5, ±√75), √75 ≈ 8,660.
    // sweep 1 + petit arc : centre (5, +√75), arc de 60° autour du point haut (5, √75 - 10) ≈ (5, -1,340).
    let offset = 75.0.squareRoot()
    let small = try SVGPathParser.parse("M0,0 A10,10 0 0 1 10,0").boundingRect
    #expect(abs(small.minX - 0) < 0.05 && abs(small.maxX - 10) < 0.05)
    #expect(abs(small.minY - (offset - 10)) < 0.05 && abs(small.maxY - 0) < 0.05)
    // sweep 1 + grand arc : centre (5, -√75), arc de 300° ; x de 5 - 10 à 5 + 10, y de -√75 - 10 ≈ -18,660 à 0.
    let large = try SVGPathParser.parse("M0,0 A10,10 0 1 1 10,0").boundingRect
    #expect(abs(large.minX + 5) < 0.05 && abs(large.maxX - 15) < 0.05)
    #expect(abs(large.minY - (-offset - 10)) < 0.05 && abs(large.maxY - 0) < 0.05)
    // sweep 0 inverse les centres : le petit arc passe sous la corde (y de 0 à 10 - √75), le grand arc la contourne par le bas.
    let smallDown = try SVGPathParser.parse("M0,0 A10,10 0 0 0 10,0").boundingRect
    #expect(abs(smallDown.maxY - (10 - offset)) < 0.05 && abs(smallDown.minY - 0) < 0.05)
    let largeDown = try SVGPathParser.parse("M0,0 A10,10 0 1 0 10,0").boundingRect
    #expect(abs(largeDown.maxY - (offset + 10)) < 0.05 && abs(largeDown.minY - 0) < 0.05)
    #expect(abs(largeDown.minX + 5) < 0.05 && abs(largeDown.maxX - 15) < 0.05)
}

@Test func quarterOfAnEllipseRotatedBy90DegreesHasTheExpectedBox() throws {
    // rx = 10, ry = 5, rotation 90° : demi-axe 10 vertical, 5 horizontal. Centre (5, 0) :
    // x = 5 - 5·sin t, y = 10·cos t. De (0,0) (t = 90°) à (5,10) (t = 0°), sens négatif (sweep 0).
    let rect = try SVGPathParser.parse("M0,0 A10,5 90 0 0 5,10").boundingRect
    #expect(abs(rect.minX - 0) < 0.02 && abs(rect.maxX - 5) < 0.02)
    #expect(abs(rect.minY - 0) < 0.02 && abs(rect.maxY - 10) < 0.02)
    let segments = SVGArc.cubicSegments(
        from: .zero, to: CGPoint(x: 5, y: 10), rx: 10, ry: 5, rotation: 90, largeArc: false, sweep: false)
    #expect(segments.count == 1)
    // Sans rotation (ou avec le mauvais centre), le point milieu ne tomberait pas sur (5 - 5·sin 45°, 10·cos 45°).
    let middle = cubicMidpoint(from: .zero, segments[0])
    #expect(abs(middle.x - (5 - 5 * sin(.pi / 4))) < 0.01 && abs(middle.y - 10 * cos(.pi / 4)) < 0.01)
}

@Test func rotatedEllipticalArcPassesThroughTheExpectedMidPoint() {
    // Ellipse centrée en (0,0), rx = 10, ry = 4, tournée de 30° : P(t) = R(30°)·(10·cos t, 4·sin t).
    // Quart de t = 0 à t = 90° (sens positif, petit arc).
    let phi = 30.0 * .pi / 180
    func point(_ angle: Double) -> CGPoint {
        let along = 10 * cos(angle)
        let across = 4 * sin(angle)
        return CGPoint(x: cos(phi) * along - sin(phi) * across, y: sin(phi) * along + cos(phi) * across)
    }
    let segments = SVGArc.cubicSegments(
        from: point(0), to: point(.pi / 2), rx: 10, ry: 4, rotation: 30, largeArc: false, sweep: true)
    #expect(segments.count == 1)
    let middle = cubicMidpoint(from: point(0), segments[0])
    let expected = point(.pi / 4)
    #expect(abs(middle.x - expected.x) < 0.01 && abs(middle.y - expected.y) < 0.01)
    // Le sens négatif (sweep 0) donne l'autre petit arc, centré à l'opposé : son milieu est ailleurs.
    let other = SVGArc.cubicSegments(
        from: point(0), to: point(.pi / 2), rx: 10, ry: 4, rotation: 30, largeArc: false, sweep: false)
    #expect(other.count == 1)
    let otherMiddle = cubicMidpoint(from: point(0), other[0])
    #expect(abs(otherMiddle.x - expected.x) > 1 || abs(otherMiddle.y - expected.y) > 1)
}

private func cubicMidpoint(from start: CGPoint, _ segment: SVGArc.CubicSegment) -> CGPoint {
    CGPoint(
        x: (start.x + 3 * segment.control1.x + 3 * segment.control2.x + segment.end.x) / 8,
        y: (start.y + 3 * segment.control1.y + 3 * segment.control2.y + segment.end.y) / 8)
}

@Test func tooSmallRadiiAreScaledUp() throws {
    let rect = try SVGPathParser.parse("M0,0 A1,1 0 0 1 10,0").boundingRect
    #expect(abs(rect.width - 10) < 0.01 && abs(rect.height - 5) < 0.05)
}

@Test func zeroRadiusArcIsALine() throws {
    let rect = try SVGPathParser.parse("M0,0 A0,5 0 0 1 10,10").boundingRect
    #expect(rect == CGRect(x: 0, y: 0, width: 10, height: 10))
}

@Test func arcSegmentsAreAtMostAQuarterTurn() {
    let half = SVGArc.cubicSegments(
        from: CGPoint(x: 0, y: 0), to: CGPoint(x: 10, y: 0), rx: 5, ry: 5, rotation: 0, largeArc: false, sweep: true)
    #expect(half.count == 2)
    #expect(half.last?.end == CGPoint(x: 10, y: 0))
    // Centre (5, 0), sweep 1 : le premier quart finit au sommet (5, -5).
    #expect(abs((half.first?.end.x ?? 0) - 5) < 1e-9 && abs((half.first?.end.y ?? 0) + 5) < 1e-9)
    let small = SVGArc.cubicSegments(
        from: CGPoint(x: 5, y: 0), to: CGPoint(x: 0, y: -5), rx: 5, ry: 5, rotation: 0, largeArc: false, sweep: false)
    #expect(small.count == 1)
}
