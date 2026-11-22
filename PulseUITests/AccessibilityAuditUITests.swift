import XCTest

/// L'audit d'accessibilité automatique d'Xcode (`performAccessibilityAudit`) sur chaque écran principal : les cinq onglets, la
/// séance en direct et son récap. Il complète la vérification à la main (`docs/app-store/verification-accessibilite.md`) : il
/// attrape les libellés manquants, les cibles trop petites, les textes coupés et les contrastes, pas l'ordre de lecture ni
/// la qualité des phrases dites. C'est Mathéo qui le lance.
final class AccessibilityAuditUITests: XCTestCase {
    private static let maxSwipes = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryMainScreenPassesTheAccessibilityAudit() throws {
        let app = XCUIApplication()
        // Mêmes arguments que `OnboardingFlowUITests` : magasin en mémoire, Santé simulée (nuit « goodNight »), horloge figée
        // au lundi 2 novembre 2026.
        app.launchArguments = [
            "-PulseStore", "inMemory",
            "-PulseHealthScenario", "goodNight",
            "-PulseNow", "2026-11-02T08:00:00+01:00"
        ]
        app.launch()

        completeOnboarding(in: app)

        // Aujourd'hui : le cadran du score est affiché une fois l'onboarding terminé.
        XCTAssertTrue(app.staticTexts["today.score"].waitForExistence(timeout: 15))
        try audit(app, screen: "Aujourd'hui")

        // Séance (l'onglet qui entraîne) : l'entrée « Séance libre » sert aussi plus bas.
        openTab("Séance", in: app)
        XCTAssertTrue(app.buttons["train.free"].waitForExistence(timeout: 10))
        try audit(app, screen: "Séance")

        openTab("Planning", in: app)
        XCTAssertTrue(app.buttons["planning.today.start"].waitForExistence(timeout: 10)
            || app.descendants(matching: .any)["planning.today"].waitForExistence(timeout: 10))
        try audit(app, screen: "Planning")

        openTab("Stats", in: app)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 10))
        try audit(app, screen: "Stats")

        openTab("Profil", in: app)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 10)
            || app.tables.firstMatch.waitForExistence(timeout: 10)
            || app.collectionViews.firstMatch.waitForExistence(timeout: 10))
        try audit(app, screen: "Profil")

        // Séance libre : l'écran de séance en direct, puis le récap après « Terminer ».
        openTab("Séance", in: app)
        tapWhenHittable(app.buttons["train.free"], in: app)
        XCTAssertTrue(app.buttons["live.finish"].waitForExistence(timeout: 15))
        try audit(app, screen: "Séance en direct")

        // Une séance libre n'a aucune série prévue : « Terminer » mène directement au récap, sans confirmation.
        tapWhenHittable(app.buttons["live.finish"], in: app)
        XCTAssertTrue(app.buttons["recap.later"].waitForExistence(timeout: 15))
        try audit(app, screen: "Récap de séance")
    }

    // MARK: Parcours

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        // Le contenu de bienvenue n'apparaît qu'une fois le modèle démarré : on attend le bouton.
        tapWhenHittable(app.buttons["onboarding.welcome.start"], in: app, timeout: 10)
        tapWhenHittable(app.buttons["onboarding.health.allow"], in: app)
        tapWhenHittable(app.buttons["onboarding.profile.continue"], in: app)
        tapWhenHittable(app.buttons["onboarding.goals.continue"], in: app)
        tapWhenHittable(app.buttons["onboarding.program.adopt"], in: app)
        XCTAssertTrue(app.staticTexts["onboarding.calibration.score"].waitForExistence(timeout: 15))
        tapWhenHittable(app.buttons["onboarding.calibration.finish"], in: app)
    }

    /// Touche l'onglet par son nom (la barre d'onglets se replie au défilement : `tapWhenHittable` la fait réapparaître).
    @MainActor
    private func openTab(_ name: String, in app: XCUIApplication) {
        tapWhenHittable(app.tabBars.buttons[name], in: app, timeout: 10)
    }

    // MARK: Audit

    /// Passe tous les types d'audit sur l'écran affiché, et nomme l'écran dans le message d'échec.
    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) throws {
        try XCTContext.runActivity(named: "Audit d'accessibilité : \(screen)") { _ in
            try app.performAccessibilityAudit { issue in
                // Seul écart écarté : un défaut de contraste sur un élément décoratif, c'est-à-dire sans texte ni action
                // (image ou conteneur sans libellé), comme la trame de points « Argentique » (`HalftoneField`, cachée à
                // VoiceOver) qui n'a aucune information à lire. Le contraste d'un texte ou d'un bouton, même posé sur la
                // trame, reste signalé. Tout autre type d'audit n'est jamais écarté.
                guard issue.auditType == .contrast, let element = issue.element else { return false }
                return (element.elementType == .image || element.elementType == .other) && element.label.isEmpty
            }
        }
    }

    // MARK: Aide

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
