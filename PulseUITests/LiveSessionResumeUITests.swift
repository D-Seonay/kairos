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
        // Sans historique, le développé couché n'a pas de charge proposée : la première coche ouvre le clavier.
        enterFirstSet(in: app, weight: [6, 0], reps: [8])
        let firstCheck = app.buttons["live.exercise.0.set.0.check"]
        tapWhenHittable(firstCheck, in: app)
        waitUntilValidated(firstCheck)
        // La première série validée sert de référence aux suivantes : une seule touche valide la deuxième.
        let secondCheck = app.buttons["live.exercise.0.set.1.check"]
        tapWhenHittable(secondCheck, in: app)
        waitUntilValidated(secondCheck)

        // Arrêt forcé, puis relance sans effacer le magasin.
        app.terminate()
        app.launchArguments = arguments
        app.launch()

        tapWhenHittable(app.buttons["session.resume"], in: app, timeout: 15)
        XCTAssertTrue(firstCheck.waitForExistence(timeout: 10))
        waitUntilValidated(firstCheck, "Série 1 non validée après la reprise")
        waitUntilValidated(secondCheck, "Série 2 non validée après la reprise")

        let thirdCheck = app.buttons["live.exercise.0.set.2.check"]
        tapWhenHittable(thirdCheck, in: app)
        waitUntilValidated(thirdCheck)
        tapWhenHittable(app.buttons["live.finish"], in: app)
        // Il reste des séries prévues : « Terminer quand même » confirme.
        tapWhenHittable(app.buttons["Terminer quand même"], in: app)
        tapWhenHittable(app.buttons["recap.save"], in: app, timeout: 15)

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "today.session.done").firstMatch
            .waitForExistence(timeout: 15))
    }

    /// La coche de la première série ouvre le clavier sur la charge : on la saisit, « Suivant » passe aux répétitions, qu'on saisit
    /// aussi (la proposition éventuelle s'efface au premier chiffre), puis on ferme le clavier pour ne pas couvrir les coches.
    @MainActor
    private func enterFirstSet(in app: XCUIApplication, weight: [Int], reps: [Int]) {
        tapWhenHittable(app.buttons["live.exercise.0.set.0.check"], in: app, timeout: 15)
        typeDigits(weight, in: app)
        tapKey("next", in: app)
        typeDigits(reps, in: app)
        let close = app.buttons["Fermer le clavier"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["live.key.next"].waitForNonExistence(timeout: 5), "Le clavier reste ouvert")
    }

    @MainActor
    private func typeDigits(_ digits: [Int], in app: XCUIApplication) {
        digits.forEach { tapKey("\($0)", in: app) }
    }

    @MainActor
    private func tapKey(_ name: String, in app: XCUIApplication) {
        let key = app.buttons["live.key.\(name)"]
        XCTAssertTrue(key.waitForExistence(timeout: 5), "Touche introuvable : \(name)")
        key.tap()
    }

    /// La validation passe par le service : l'étiquette de la coche change après le toucher. On attend qu'elle finisse par
    /// « validée » (et non « non validée »).
    @MainActor
    private func waitUntilValidated(_ check: XCUIElement, _ message: String = "Série non validée", timeout: TimeInterval = 10) {
        let validated = NSPredicate(format: "label ENDSWITH %@", ", validée")
        let expectation = XCTNSPredicateExpectation(predicate: validated, object: check)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, "\(message) : \(check.label)")
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
