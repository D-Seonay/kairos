import PulseDesignSystem

/// Les trois retours haptiques de la séance (spec M4 §14.4). Le modèle les appelle par ce biais, pour que les tests les comptent.
struct LiveSessionHaptics {
    var light: @MainActor () -> Void
    var validation: @MainActor () -> Void
    var restEnded: @MainActor () -> Void

    static let system = LiveSessionHaptics(
        light: { PulseHaptics.light() }, validation: { PulseHaptics.validation() }, restEnded: { PulseHaptics.restEnded() })
}
