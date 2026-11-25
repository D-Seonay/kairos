import XCTest

final class OnboardingFlowUITests: XCTestCase {
    private static let maxSwipes = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingReachesTheFirstScoreThenToday() {
        let app = XCUIApplication()
        // L'horloge figée par `-PulseNow` est lue avec le fuseau du simulateur : celui de Paris garde le même jour, quel que
        // soit le fuseau du Mac qui lance les tests (Xcode Cloud compris).
        app.launchEnvironment["TZ"] = "Europe/Paris"
        // Magasin en mémoire, Santé simulée (nuit « goodNight »), horloge figée au lundi 2 novembre 2026.
        app.launchArguments = [
            "-PulseStore", "inMemory",
            "-PulseHealthScenario", "goodNight",
            "-PulseNow", "2026-11-02T08:00:00+01:00"
        ]
        app.launch()

        // Le contenu de bienvenue n'apparaît qu'une fois le modèle démarré : on attend le bouton.
        tapWhenHittable(app.buttons["onboarding.welcome.start"], in: app, timeout: 10)
        tapWhenHittable(app.buttons["onboarding.health.allow"], in: app)
        tapWhenHittable(app.buttons["onboarding.profile.continue"], in: app)
        tapWhenHittable(app.buttons["onboarding.goals.continue"], in: app)
        tapWhenHittable(app.buttons["onboarding.program.adopt"], in: app)

        // Le cadran porte l'identifiant et le trait « texte statique » : il est exposé comme `staticText`.
        let calibrationScore = app.staticTexts["onboarding.calibration.score"]
        XCTAssertTrue(calibrationScore.waitForExistence(timeout: 15))
        // Le cadran dit le score et la catégorie d'un seul élément (VoiceOver) : le libellé contient le nom de la catégorie.
        XCTAssertTrue(calibrationScore.label.localizedCaseInsensitiveContains("forme optimale"))

        tapWhenHittable(app.buttons["onboarding.calibration.finish"], in: app)

        // Même cadran que sur la calibration : `staticText` grâce au trait ajouté sur la jauge.
        XCTAssertTrue(app.staticTexts["today.score"].waitForExistence(timeout: 15))
        // Le titre de séance a le trait « en-tête » : on interroge `.any` pour ne pas dépendre du type
        // sous lequel XCTest rapporte un en-tête (`staticText` ou `other`).
        let sessionTitle = app.descendants(matching: .any).matching(identifier: "today.session.title").firstMatch
        XCTAssertTrue(sessionTitle.waitForExistence(timeout: 5))
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
