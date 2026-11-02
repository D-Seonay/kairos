import Foundation

/// La saisie du clavier numérique intégré (spec M4 §14.4) : un tampon texte à la française, sans clavier système. Une machine
/// pure : chaque touche rend la valeur du tampon, `nil` quand il est vide.
public struct KeypadInput: Sendable, Equatable {
    public enum Key: Sendable, Equatable {
        case digit(Int)
        case comma
        case delete
        case minus
        case plus
        /// « Suivant » ne change pas le tampon : le modèle de séance déplace le champ.
        case next
    }

    /// Le pas de la charge est arrondi au quart de kilo.
    static let weightGranularity = 0.25
    static let repsStep = 1.0
    static let secondsStep = 5.0

    public let field: KeypadField.Kind
    public let increment: Double
    public private(set) var text = ""
    /// Vrai juste après `start(with:)` et un pas −/+ : le chiffre suivant remplace la valeur au lieu de s'y ajouter.
    private var replacesOnNextKey = false

    public init(field: KeypadField.Kind, increment: Double) {
        self.field = field
        self.increment = increment
    }

    /// Ouvre le champ sur sa valeur actuelle, qui s'efface au premier chiffre.
    public mutating func start(with value: Double?) {
        text = value.map(Self.format) ?? ""
        replacesOnNextKey = value != nil
    }

    /// Applique la touche et rend la valeur du tampon.
    @discardableResult
    public mutating func apply(_ key: Key) -> Double? {
        switch key {
        case let .digit(digit):
            append(String(digit))
        case .comma:
            append(",")
        case .delete:
            replacesOnNextKey = false
            text = String(text.dropLast())
        case .minus:
            step(by: -stepSize)
        case .plus:
            step(by: stepSize)
        case .next:
            break
        }
        return value
    }

    /// La valeur du tampon ; `nil` s'il est vide.
    public var value: Double? {
        text.isEmpty ? nil : Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private var stepSize: Double {
        switch field {
        case .weight: increment
        case .reps: Self.repsStep
        case .duration: Self.secondsStep
        }
    }

    private var maxIntegerDigits: Int {
        switch field {
        case .weight: 4
        case .reps: 3
        case .duration: 5
        }
    }

    private var maxDecimals: Int { field == .weight ? 2 : 0 }

    private mutating func append(_ character: String) {
        // Une virgule refusée ne touche pas au tampon : elle n'efface pas la valeur qui attend d'être remplacée.
        if character == ",", maxDecimals == 0 { return }
        if replacesOnNextKey {
            text = ""
            replacesOnNextKey = false
        }
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        let integer = parts.first.map(String.init) ?? ""
        let decimals = parts.count > 1 ? String(parts[1]) : nil
        if character == "," {
            guard decimals == nil else { return }
            text = (integer.isEmpty ? "0" : integer) + ","
        } else if let decimals {
            guard decimals.count < maxDecimals else { return }
            text += character
        } else if integer == "0" {
            text = character
        } else if integer.count < maxIntegerDigits {
            text += character
        }
    }

    private mutating func step(by delta: Double) {
        var next = max(0, (value ?? 0) + delta)
        if field == .weight { next = (next / Self.weightGranularity).rounded() * Self.weightGranularity }
        text = Self.format(next)
        replacesOnNextKey = true
    }

    /// « 67,5 », « 70 » : au plus deux décimales, sans zéros inutiles.
    private static func format(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        return text.replacingOccurrences(of: ".", with: ",")
    }
}
