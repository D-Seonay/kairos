import XCTest

final class LiveSessionResumeUITests: XCTestCase {
    private static let maxSwipes = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Une séance Push du lundi 2 novembre 2026 : deux séries validées, arrêt forcé, reprise, dernière série, fin, récap.
    @MainActor
    func testCompleteSessionSurvivesAForcedQuit() {
        let app = XCUIApplication()
        // Magasin sur disque et profil PPL créé au premier lancement : le second lancement retrouve la séance en cours.
        let arguments = [
            "-PulseStore", "disk",
            "-PulseSeed", "onboardedPPL",
            "-PulseHealthScenario", "goodNight",
            "-PulseNow", "2026-11-02T08:00:00+01:00"
        ]
        app.launchArguments = arguments + ["-PulseResetStore", "YES"]
        app.launch()

        tapWhenHittable(app.buttons["today.session.start"], in: app, timeout: 15)
        tapWhenHittable(app.buttons["live.exercise.0.set.0.check"], in: app, timeout: 15)
        tapWhenHittable(app.buttons["live.exercise.0.set.1.check"], in: app)
        XCTAssertTrue(isValidated(app.buttons["live.exercise.0.set.1.check"]))

        // Arrêt forcé, puis relance sans effacer le magasin.
        app.terminate()
        app.launchArguments = arguments
        app.launch()

        tapWhenHittable(app.buttons["session.resume"], in: app, timeout: 15)
        XCTAssertTrue(app.buttons["live.exercise.0.set.0.check"].waitForExistence(timeout: 10))
        XCTAssertTrue(isValidated(app.buttons["live.exercise.0.set.0.check"]), "Série 1 non validée après la reprise")
        XCTAssertTrue(isValidated(app.buttons["live.exercise.0.set.1.check"]), "Série 2 non validée après la reprise")

        tapWhenHittable(app.buttons["live.exercise.0.set.2.check"], in: app)
        tapWhenHittable(app.buttons["live.finish"], in: app)
        // Il reste des séries prévues : « Terminer quand même » confirme.
        tapWhenHittable(app.buttons["Terminer quand même"], in: app)
        tapWhenHittable(app.buttons["recap.save"], in: app, timeout: 15)

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "today.session.done").firstMatch
            .waitForExistence(timeout: 15))
    }

    /// L'étiquette d'une coche finit par « validée » (et non « non validée ») une fois la série validée.
    @MainActor
    private func isValidated(_ check: XCUIElement) -> Bool {
        check.label.hasSuffix(", validée")
    }

    /// Attend l'élément, le fait défiler vers le haut jusqu'à ce qu'il soit touchable (au plus `maxSwipes` fois), puis le touche.
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
