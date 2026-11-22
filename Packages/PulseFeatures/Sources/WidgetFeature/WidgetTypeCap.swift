import SwiftUI

/// Les plafonds de taille de texte des widgets, un par widget. Aucune famille de widget (158 pt, 338 x 158, 338 x 354, le cercle de
/// 76 pt, le rectangle de 66 pt) ne tient aux tailles d'accessibilité : le texte grandit jusqu'à `xxxLarge`, l'étiquette VoiceOver
/// porte le reste.
///
/// Chaque vue publique applique son plafond autour de la vue qui déclare les `@ScaledMetric` : un `ScaledMetric` lit
/// l'environnement de la vue qui le déclare, un plafond posé dans le corps de cette même vue ne le plafonnerait pas.
public enum WidgetTypeCap {
    public static let loadSmall: DynamicTypeSize = .xxxLarge
    public static let loadCircular: DynamicTypeSize = .xxxLarge
    public static let streakSmall: DynamicTypeSize = .xxxLarge
    public static let streakCircular: DynamicTypeSize = .xxxLarge
    public static let nextWorkoutSmall: DynamicTypeSize = .xxxLarge
    public static let recoverySmall: DynamicTypeSize = .xxxLarge
    public static let sessionMedium: DynamicTypeSize = .xxxLarge
    public static let sessionRectangular: DynamicTypeSize = .xxxLarge
    public static let weekLarge: DynamicTypeSize = .xxxLarge

    /// Tous les plafonds, pour le test : jamais au-delà de `accessibility3`.
    static let all: [DynamicTypeSize] = [loadSmall, loadCircular, streakSmall, streakCircular, nextWorkoutSmall, recoverySmall,
                                         sessionMedium, sessionRectangular, weekLarge]
}
