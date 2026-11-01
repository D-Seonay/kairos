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

@Test func arcsMatchTheCircleAndHonourFlags() throws {
    // Grand arc, sweep 1 : passe par le haut du cercle de centre (5, 0).
    let large = try SVGPathParser.parse("M0,0 A5,5 0 1 1 10,0").boundingRect
    #expect(abs(large.height - 5) < 0.05 && large.minY < -4.9)
    let small = try SVGPathParser.parse("M0,0 A5,5 0 0 0 10,0").boundingRect
    #expect(small.maxY > 4.9)
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
    #expect(half.last?.2 == CGPoint(x: 10, y: 0))
    let small = SVGArc.cubicSegments(
        from: CGPoint(x: 5, y: 0), to: CGPoint(x: 0, y: -5), rx: 5, ry: 5, rotation: 0, largeArc: false, sweep: false)
    #expect(small.count == 1)
}

@Test func rotatedEllipticalArcEndsOnItsTarget() {
    let segments = SVGArc.cubicSegments(
        from: CGPoint(x: 0, y: 0), to: CGPoint(x: 8, y: 3), rx: 6, ry: 2, rotation: 30, largeArc: true, sweep: false)
    #expect(!segments.isEmpty)
    #expect(segments.last?.2 == CGPoint(x: 8, y: 3))
}
