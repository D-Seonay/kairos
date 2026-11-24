import PulseDesignSystem

/// Les retours haptiques de la séance (spec M4 §14.4). Le modèle les appelle par ce biais, pour que les tests les comptent.
/// `exerciseDone` et `sessionDone` suivent la double vibration de la validation quand elle termine un exercice ou la séance ;
/// `tick` marque un ajout et les trois dernières secondes du repos ; `soft` un pas en arrière (dévalider, supprimer).
struct LiveSessionHaptics {
    var light: @MainActor () -> Void
    var validation: @MainActor () -> Void
    var restEnded: @MainActor () -> Void
    var exerciseDone: @MainActor () -> Void = {}
    var sessionDone: @MainActor () -> Void = {}
    var tick: @MainActor () -> Void = {}
    var soft: @MainActor () -> Void = {}

    static let system = LiveSessionHaptics(
        light: { PulseHaptics.light() }, validation: { PulseHaptics.validation() }, restEnded: { PulseHaptics.restEnded() },
        exerciseDone: { PulseHaptics.success() }, sessionDone: { PulseHaptics.celebration() },
        tick: { PulseHaptics.tick() }, soft: { PulseHaptics.soft() })
}
