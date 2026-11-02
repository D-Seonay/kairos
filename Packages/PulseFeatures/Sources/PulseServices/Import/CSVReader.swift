/// Lecteur CSV (RFC 4180) : champs entre guillemets avec `""`, virgules et retours à la ligne dans les champs, fins de
/// ligne `\n`, `\r\n` ou `\r`, BOM UTF-8 ignoré, lignes vides ignorées.
enum CSVReader {
    struct Record: Equatable {
        /// Numéro (à partir de 1) de la ligne du fichier où commence l'enregistrement.
        let line: Int
        let fields: [String]
    }

    static func records(_ text: String) -> [[String]] {
        numberedRecords(text).map(\.fields)
    }

    static func numberedRecords(_ text: String) -> [Record] {
        var parser = Parser()
        let scalars = Array(text.unicodeScalars.drop { $0 == "\u{FEFF}" })
        var index = 0
        while index < scalars.count {
            index += parser.consume(scalars[index], next: index + 1 < scalars.count ? scalars[index + 1] : nil)
        }
        return parser.finish()
    }

    private struct Parser {
        private var records: [Record] = []
        private var fields: [String] = []
        private var field = String.UnicodeScalarView()
        private var inQuotes = false
        private var line = 1
        private var recordLine = 1

        /// Lit un caractère ; rend le nombre de caractères consommés (2 quand `next` est absorbé).
        mutating func consume(_ scalar: Unicode.Scalar, next: Unicode.Scalar?) -> Int {
            if inQuotes {
                return consumeQuoted(scalar, next: next)
            }
            switch scalar {
            case "\"" where field.isEmpty:
                inQuotes = true
            case ",":
                endField()
            case "\r" where next == "\n":
                endRecord()
                return 2
            case "\r", "\n":
                endRecord()
            default:
                field.append(scalar)
            }
            return 1
        }

        mutating func finish() -> [Record] {
            endRecord()
            return records
        }

        private mutating func consumeQuoted(_ scalar: Unicode.Scalar, next: Unicode.Scalar?) -> Int {
            switch scalar {
            case "\"" where next == "\"":
                field.append("\"")
                return 2
            case "\"":
                inQuotes = false
            case "\n":
                line += 1
                field.append(scalar)
            default:
                field.append(scalar)
            }
            return 1
        }

        private mutating func endField() {
            fields.append(String(field))
            field = String.UnicodeScalarView()
        }

        private mutating func endRecord() {
            endField()
            if fields != [""] {
                records.append(Record(line: recordLine, fields: fields))
            }
            fields = []
            line += 1
            recordLine = line
        }
    }
}
