import CoreGraphics
import SwiftUI

enum SVGPathError: Error, Equatable {
    case unexpectedCharacter(Character, offset: Int)
    case missingNumber(command: Character, offset: Int)
}

/// Lit l'attribut `d` d'un tracé SVG : `M m L l H h V v C c Q q A a Z z`, répétition implicite incluse.
enum SVGPathParser {
    static func parse(_ data: String) throws -> Path {
        var interpreter = SVGPathInterpreter(data)
        return try interpreter.run()
    }
}

private struct SVGPathInterpreter {
    private static let commands: Set<Character> = ["M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "Q", "q", "A", "a", "Z", "z"]

    private var lexer: SVGPathLexer
    private var path = Path()
    private var current = CGPoint.zero
    private var subpathStart = CGPoint.zero

    init(_ data: String) {
        lexer = SVGPathLexer(data)
    }

    mutating func run() throws -> Path {
        var previous: Character?
        lexer.skipSeparators()
        while let scalar = lexer.peek {
            let offset = lexer.offset
            let command: Character
            if lexer.startsNumber {
                guard let repeated = Self.implicitCommand(after: previous) else {
                    throw SVGPathError.unexpectedCharacter(Character(scalar), offset: offset)
                }
                command = repeated
            } else {
                command = Character(scalar)
                guard Self.commands.contains(command), previous != nil || "Mm".contains(command) else {
                    throw SVGPathError.unexpectedCharacter(command, offset: offset)
                }
                lexer.advance()
            }
            try execute(command)
            previous = Self.implicitCommand(afterExecuting: command)
            lexer.skipSeparators()
        }
        return path
    }

    /// Après un `M`, les paires suivantes sont des `L` ; après un `Z`, rien ne peut se répéter.
    private static func implicitCommand(afterExecuting command: Character) -> Character? {
        switch command {
        case "M": "L"
        case "m": "l"
        case "Z", "z": "z"
        default: command
        }
    }

    private static func implicitCommand(after previous: Character?) -> Character? {
        guard let previous, previous != "z" else { return nil }
        return previous
    }

    private mutating func execute(_ command: Character) throws {
        let origin = command.isLowercase ? current : .zero
        switch Character(command.lowercased()) {
        case "m":
            let target = try point(command, origin: origin)
            path.move(to: target)
            subpathStart = target
            current = target
        case "l":
            lineTo(try point(command, origin: origin))
        case "h":
            lineTo(CGPoint(x: origin.x + (try lexer.number(for: command)), y: current.y))
        case "v":
            lineTo(CGPoint(x: current.x, y: (command.isLowercase ? current.y : 0) + (try lexer.number(for: command))))
        case "c":
            let control1 = try point(command, origin: origin)
            let control2 = try point(command, origin: origin)
            let target = try point(command, origin: origin)
            path.addCurve(to: target, control1: control1, control2: control2)
            current = target
        case "q":
            let control = try point(command, origin: origin)
            let target = try point(command, origin: origin)
            path.addQuadCurve(to: target, control: control)
            current = target
        case "a":
            try arc(command, origin: origin)
        default:
            path.closeSubpath()
            current = subpathStart
        }
    }

    private mutating func lineTo(_ target: CGPoint) {
        path.addLine(to: target)
        current = target
    }

    private mutating func arc(_ command: Character, origin: CGPoint) throws {
        let radiusX = try lexer.number(for: command)
        let radiusY = try lexer.number(for: command)
        let rotation = try lexer.number(for: command)
        let largeArc = try lexer.flag(for: command)
        let sweep = try lexer.flag(for: command)
        let target = try point(command, origin: origin)
        let segments = SVGArc.cubicSegments(
            from: current, to: target, rx: radiusX, ry: radiusY, rotation: rotation, largeArc: largeArc, sweep: sweep)
        for (control1, control2, end) in segments {
            path.addCurve(to: end, control1: control1, control2: control2)
        }
        current = target
    }

    private mutating func point(_ command: Character, origin: CGPoint) throws -> CGPoint {
        let x = try lexer.number(for: command)
        let y = try lexer.number(for: command)
        return CGPoint(x: origin.x + x, y: origin.y + y)
    }
}
