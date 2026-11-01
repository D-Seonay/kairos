/// Lexeur à un passage sur les scalaires Unicode d'un attribut `d` SVG.
struct SVGPathLexer {
    private let scalars: [Unicode.Scalar]
    private(set) var offset = 0

    init(_ data: String) {
        scalars = Array(data.unicodeScalars)
    }

    var peek: Unicode.Scalar? {
        offset < scalars.count ? scalars[offset] : nil
    }

    /// Vrai si le prochain scalaire peut ouvrir un nombre (signe, chiffre ou point).
    var startsNumber: Bool {
        guard let scalar = peek else { return false }
        return Self.isDigit(scalar) || scalar == "-" || scalar == "+" || scalar == "."
    }

    mutating func advance() {
        offset += 1
    }

    /// Saute les blancs et les virgules.
    mutating func skipSeparators() {
        while let scalar = peek, scalar == "," || scalar == " " || scalar == "\n" || scalar == "\t" || scalar == "\r" {
            offset += 1
        }
    }

    mutating func number(for command: Character) throws -> Double {
        skipSeparators()
        let start = offset
        guard let value = scanNumber() else {
            throw SVGPathError.missingNumber(command: command, offset: start)
        }
        return value
    }

    /// Les drapeaux d'arc sont un seul caractère `0` ou `1`, sans séparateur obligatoire.
    mutating func flag(for command: Character) throws -> Bool {
        skipSeparators()
        guard let scalar = peek, scalar == "0" || scalar == "1" else {
            throw SVGPathError.missingNumber(command: command, offset: offset)
        }
        offset += 1
        return scalar == "1"
    }

    private mutating func scanNumber() -> Double? {
        let start = offset
        if let sign = peek, sign == "-" || sign == "+" { offset += 1 }
        let integerDigits = skipDigits()
        var fractionDigits = 0
        if peek == "." {
            offset += 1
            fractionDigits = skipDigits()
        }
        guard integerDigits + fractionDigits > 0 else {
            offset = start
            return nil
        }
        skipExponent()
        var text = String.UnicodeScalarView()
        text.append(contentsOf: scalars[start..<offset])
        guard let value = Double(String(text)), value.isFinite else {
            offset = start
            return nil
        }
        return value
    }

    /// N'avale l'exposant que s'il est complet (`e`, signe facultatif, au moins un chiffre).
    private mutating func skipExponent() {
        guard let marker = peek, marker == "e" || marker == "E" else { return }
        let saved = offset
        offset += 1
        if let sign = peek, sign == "-" || sign == "+" { offset += 1 }
        if skipDigits() == 0 { offset = saved }
    }

    private mutating func skipDigits() -> Int {
        let start = offset
        while let scalar = peek, Self.isDigit(scalar) { offset += 1 }
        return offset - start
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x30 && scalar.value <= 0x39
    }
}
