import XCTest

/// Spec M5 §12 : créer un complément depuis l'accueil, puis le cocher. L'action « Pris » de la notification réelle se vérifie
/// à la main sur l'iPhone.
final class SupplementsUITests: XCTestCase {
    private static let maxSwipes = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateASupplementThenTakeIt() {
        let app = XCUIApplication()
        // L'horloge figée par `-PulseNow` est lue avec le fuseau du simulateur : celui de Paris garde le même jour, quel que
        // soit le fuseau du Mac qui lance les tests (Xcode Cloud compris).
        app.launchEnvironment["TZ"] = "Europe/Paris"
        app.launchArguments = [
            "-PulseStore", "inMemory",
            "-PulseSeed", "onboardedPPL",
            "-PulseHealthScenario", "goodNight",
            "-PulseNow", "2026-11-02T07:00:00+01:00"
        ]
        app.launch()

        tapWhenHittable(app.buttons["supplements.card"], in: app, timeout: 15)
        tapWhenHittable(app.buttons["supplements.add"], in: app)
        tapWhenHittable(app.buttons["Créatine"], in: app)
        let dose = app.textFields["supplements.form.dose"]
        tapWhenHittable(dose, in: app)
        dose.typeText("5")
        tapWhenHittable(app.buttons["supplements.form.save"], in: app)

        // Créatine à 8:00, et il est 7:00 : c'est la prochaine prise.
        // La coche est un interrupteur (nom = le complément, valeur « Pris » / « Pas pris ») : XCTest peut la ranger sous
        // `button` ou `switch`, on interroge donc `.any`.
        let check = app.descendants(matching: .any).matching(identifier: "supplements.check.Créatine").firstMatch
        tapWhenHittable(check, in: app, timeout: 10)
        let summary = app.descendants(matching: .any).matching(identifier: "supplements.summary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label CONTAINS %@", "sur 1 pris")
        expectation(for: predicate, evaluatedWith: summary)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(summary.label.hasPrefix("1"), "Prise non comptée : \(summary.label)")
    }

    @MainActor
    private func tapWhenHittable(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Élément introuvable : \(element)")
        var swipes = 0
        while !element.isHittable, swipes < Self.maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "Élément non touchable après \(swipes) défilements : \(element)")
        element.tap()
    }
}
