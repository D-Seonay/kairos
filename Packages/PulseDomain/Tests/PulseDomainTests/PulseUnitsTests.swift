import Foundation
@testable import PulseDomain
import Testing

@Suite("Unités d'affichage")
struct PulseUnitsTests {
    private let metric = PulseUnits(weightUnit: .kg, measurementSystem: .metric)
    private let pounds = PulseUnits(weightUnit: .lb, measurementSystem: .metric)
    private let imperial = PulseUnits(weightUnit: .kg, measurementSystem: .us)

    @Test("kilos : virgule décimale, aucune décimale superflue")
    func kilograms() {
        #expect(metric.weight(82.5, maxFractionDigits: 1) == "82,5 kg")
        #expect(metric.weight(80, maxFractionDigits: 2) == "80 kg")
        #expect(metric.weight(1.25, maxFractionDigits: 2) == "1,25 kg")
        #expect(metric.weightNumber(62.5, maxFractionDigits: 1) == "62,5")
        #expect(metric.weightSymbol == "kg")
    }

    @Test("kilos groupés : espace fine insécable entre les milliers")
    func groupedKilograms() {
        #expect(metric.weight(12_450, maxFractionDigits: 1, grouped: true) == "12\u{202F}450 kg")
        #expect(metric.weight(12_450, maxFractionDigits: 1) == "12450 kg")
    }

    @Test("livres : conversion à l'affichage, retour en kilos à la saisie")
    func poundsConversion() {
        #expect(pounds.weight(100, maxFractionDigits: 1) == "220,5 lb")
        #expect(pounds.weightSymbol == "lb")
        #expect(abs(pounds.displayedWeight(kilograms: 100) - 220.462_262) < 0.000_1)
        #expect(abs(pounds.kilograms(displayed: 220.462_262_185) - 100) < 0.000_001)
        #expect(metric.kilograms(displayed: 82.5) == 82.5)
    }

    @Test("kilomètres")
    func kilometres() {
        #expect(metric.distance(meters: 8_420, maxFractionDigits: 2) == "8,42 km")
        #expect(metric.distance(meters: 5_000, maxFractionDigits: 1) == "5 km")
        #expect(metric.distanceNumber(meters: 7_500, maxFractionDigits: 1) == "7,5")
        #expect(metric.distanceSymbol == "km")
        #expect(metric.meters(displayed: 7.5) == 7_500)
    }

    @Test("miles, d'après le système de mesure de la région")
    func miles() {
        #expect(imperial.distanceUnit == .mi)
        #expect(PulseUnits(weightUnit: .kg, measurementSystem: .uk).distanceUnit == .mi)
        #expect(imperial.distance(meters: 8_420, maxFractionDigits: 2) == "5,23 mi")
        #expect(imperial.distanceSymbol == "mi")
        #expect(imperial.meters(displayed: 1) == 1_609.344)
        #expect(abs(imperial.displayedDistance(kilometres: 1.609_344) - 1) < 0.000_001)
        #expect(metric.displayedDistance(kilometres: 7.5) == 7.5)
        #expect(metric.distance(kilometres: 7.5, maxFractionDigits: 1) == "7,5 km")
        #expect(imperial.distance(kilometres: 10, maxFractionDigits: 1) == "6,2 mi")
        // Le poids suit le profil, pas la région.
        #expect(imperial.weight(80, maxFractionDigits: 1) == "80 kg")
    }

    @Test("allure en min/km")
    func paceKilometres() {
        #expect(metric.pace(secondsPerKilometer: 329) == "5'29\"/km")
        #expect(metric.pace(secondsPerKilometer: 305) == "5'05\"/km")
        #expect(metric.paceSeconds(secondsPerKilometer: 329) == 329)
        #expect(metric.paceSuffix == "/km")
    }

    @Test("allure en min/mi")
    func paceMiles() {
        #expect(imperial.paceSeconds(secondsPerKilometer: 329) == 529)
        #expect(imperial.pace(secondsPerKilometer: 329) == "8'49\"/mi")
        #expect(imperial.paceSuffix == "/mi")
    }

    @Test("une valeur non finie s'affiche « — », sans unité")
    func nonFinite() {
        #expect(metric.weight(.nan, maxFractionDigits: 1) == "\u{2014}")
        #expect(metric.distance(meters: .infinity, maxFractionDigits: 1) == "\u{2014}")
    }

    @Test("l'app reste en kilos et en kilomètres tant que les saisies ne sont pas converties")
    func currentStaysMetric() {
        #expect(PulseUnits.current.weightUnit == .kg)
        #expect(PulseUnits.current.distanceUnit == .km)
    }

    @Test("la distance suit le système de mesure de la locale")
    func distanceFromLocale() {
        let american = PulseUnits(weightUnit: .lb, measurementSystem: Locale(identifier: "en_US").measurementSystem)
        #expect(american.distanceUnit == .mi)
        #expect(american.weight(100, maxFractionDigits: 1) == "220,5 lb")
        #expect(PulseUnits(measurementSystem: Locale(identifier: "fr_FR").measurementSystem).distanceUnit == .km)
    }
}
