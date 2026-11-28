import Foundation

/// L'unité des distances affichées : kilomètres, ou miles dans une région au système de mesure américain ou britannique.
public enum DistanceUnit: String, Sendable, CaseIterable {
    case km
    case mi
}

/// Les unités d'affichage (prérequis de la version anglaise, #95). Tout est stocké en kilos et en mètres ; seuls l'affichage et
/// la saisie convertissent. Le poids suit `UserProfile.weightUnit`, la distance le système de mesure de la région
/// (`Locale.current.measurementSystem`) : aucun champ de profil en plus. Les nombres gardent la virgule décimale française
/// et aucune décimale superflue, comme `PulseFormat` : en français avec les réglages par défaut, rien ne change à l'écran.
public struct PulseUnits: Sendable, Equatable {
    static let poundsPerKilogram = 2.204_622_621_848_776
    static let metersPerMile = 1_609.344
    private static let dash = "\u{2014}"

    public let weightUnit: WeightUnit
    public let distanceUnit: DistanceUnit
    let locale: Locale

    public init(weightUnit: WeightUnit = .kg, measurementSystem: Locale.MeasurementSystem = Locale.current.measurementSystem,
                locale: Locale = Locale(identifier: "fr_FR")) {
        self.weightUnit = weightUnit
        distanceUnit = measurementSystem == .metric ? .km : .mi
        self.locale = locale
    }

    // MARK: - Unités de l'app

    /// Les unités de l'app : kilos et kilomètres pour l'instant. Les saisies (séries, disques, pesée, corrections) sont encore en
    /// kilos et en kilomètres ; afficher des livres ou des miles avant de les convertir mélangerait les unités. Une fois les
    /// saisies converties et le choix kg / lb rétabli dans Réglages (#132, #95), `current` lira l'unité du profil et le système
    /// de mesure de la région.
    public static let current = PulseUnits(weightUnit: .kg, measurementSystem: .metric)

    // MARK: - Poids

    /// « kg » ou « lb ».
    public var weightSymbol: String { weightUnit.rawValue }

    public func displayedWeight(kilograms: Double) -> Double {
        weightUnit == .kg ? kilograms : kilograms * Self.poundsPerKilogram
    }

    /// Une saisie dans l'unité affichée, ramenée en kilos pour le stockage.
    public func kilograms(displayed value: Double) -> Double {
        weightUnit == .kg ? value : value / Self.poundsPerKilogram
    }

    /// « 62,5 », « 12 450 » (groupé), dans l'unité affichée, sans symbole.
    public func weightNumber(_ kilograms: Double, maxFractionDigits: Int, grouped: Bool = false) -> String {
        number(displayedWeight(kilograms: kilograms), maxFractionDigits: maxFractionDigits, grouped: grouped)
    }

    /// « 82,5 kg », « 220,5 lb ». Une valeur non finie donne « — ».
    public func weight(_ kilograms: Double, maxFractionDigits: Int, grouped: Bool = false) -> String {
        withSymbol(weightNumber(kilograms, maxFractionDigits: maxFractionDigits, grouped: grouped), weightSymbol)
    }

    // MARK: - Distance

    /// « km » ou « mi ».
    public var distanceSymbol: String { distanceUnit.rawValue }

    /// Des mètres en kilomètres ou en miles.
    public func displayedDistance(meters: Double) -> Double {
        meters / (distanceUnit == .km ? 1_000 : Self.metersPerMile)
    }

    /// Des kilomètres (objectifs de course) en kilomètres ou en miles ; tels quels en kilomètres, sans aller-retour par les mètres.
    public func displayedDistance(kilometres: Double) -> Double {
        distanceUnit == .km ? kilometres : kilometres * 1_000 / Self.metersPerMile
    }

    /// Une saisie en kilomètres ou en miles, ramenée en mètres pour le stockage.
    public func meters(displayed value: Double) -> Double {
        value * (distanceUnit == .km ? 1_000 : Self.metersPerMile)
    }

    /// « 7,5 », dans l'unité affichée, sans symbole.
    public func distanceNumber(meters: Double, maxFractionDigits: Int, grouped: Bool = false) -> String {
        number(displayedDistance(meters: meters), maxFractionDigits: maxFractionDigits, grouped: grouped)
    }

    /// « 8,42 km », « 5,23 mi ». Une valeur non finie donne « — ».
    public func distance(meters: Double, maxFractionDigits: Int, grouped: Bool = false) -> String {
        withSymbol(distanceNumber(meters: meters, maxFractionDigits: maxFractionDigits, grouped: grouped), distanceSymbol)
    }

    /// « 7,5 km » d'un objectif en kilomètres, « 4,7 mi ».
    public func distance(kilometres: Double, maxFractionDigits: Int, grouped: Bool = false) -> String {
        withSymbol(distanceNumber(kilometres: kilometres, maxFractionDigits: maxFractionDigits, grouped: grouped), distanceSymbol)
    }

    /// « 7,5 » d'un objectif en kilomètres, dans l'unité affichée, sans symbole.
    public func distanceNumber(kilometres: Double, maxFractionDigits: Int, grouped: Bool = false) -> String {
        number(displayedDistance(kilometres: kilometres), maxFractionDigits: maxFractionDigits, grouped: grouped)
    }

    // MARK: - Allure

    /// « /km » ou « /mi ».
    public var paceSuffix: String { "/\(distanceSymbol)" }

    /// Les secondes par unité affichée, arrondies, d'une allure en secondes par kilomètre.
    public func paceSeconds(secondsPerKilometer: Double) -> Int {
        let seconds = distanceUnit == .km ? secondsPerKilometer : secondsPerKilometer * Self.metersPerMile / 1_000
        guard seconds.isFinite else { return 0 }
        return Int(seconds.rounded())
    }

    /// « 5'29"/km », « 8'49"/mi ».
    public func pace(secondsPerKilometer: Double) -> String {
        let seconds = paceSeconds(secondsPerKilometer: secondsPerKilometer)
        let rest = seconds % 60
        return "\(seconds / 60)'\(rest < 10 ? "0" : "")\(rest)\"\(paceSuffix)"
    }

    // MARK: - Nombres

    private func number(_ value: Double, maxFractionDigits: Int, grouped: Bool) -> String {
        guard value.isFinite else { return Self.dash }
        let style = FloatingPointFormatStyle<Double>.number
            .locale(locale)
            .precision(.fractionLength(0...max(0, maxFractionDigits)))
            .grouping(grouped ? .automatic : .never)
        return value.formatted(style)
    }

    private func withSymbol(_ number: String, _ symbol: String) -> String {
        number == Self.dash ? number : "\(number) \(symbol)"
    }
}
