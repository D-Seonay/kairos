import SwiftUI

/// Le mouvement de l'app, soumis au réglage « Réduire les animations ». Toute animation et toute transition passe par ici :
/// avec le réglage actif, une animation disparaît, une transition devient un fondu et les chiffres changent sans rouler.
public enum PulseMotion {
    /// L'animation à jouer : aucune quand « Réduire les animations » est actif.
    public static func resolved(_ animation: Animation?, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// La transition à jouer : un simple fondu quand « Réduire les animations » est actif.
    public static func resolved(_ transition: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }

    /// Remplace `withAnimation` : le changement a lieu sans animation quand « Réduire les animations » est actif. Une
    /// animation en cours est alors arrêtée, comme avec `withAnimation(nil)`.
    public static func perform(_ animation: Animation?, reduceMotion: Bool, _ body: () -> Void) {
        withAnimation(resolved(animation, reduceMotion: reduceMotion), body)
    }
}

private struct PulseAnimationModifier<Value: Equatable>: ViewModifier {
    let animation: Animation?
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(PulseMotion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

private struct PulseTransitionModifier: ViewModifier {
    let transition: AnyTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(PulseMotion.resolved(transition, reduceMotion: reduceMotion))
    }
}

private struct PulseNumericTransitionModifier: ViewModifier {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion ? .identity : .numericText(value: value))
    }
}

public extension View {
    /// `animation(_:value:)`, sans animation quand « Réduire les animations » est actif.
    func pulseAnimation(_ animation: Animation?, value: some Equatable) -> some View {
        modifier(PulseAnimationModifier(animation: animation, value: value))
    }

    /// `transition(_:)`, réduite à un fondu quand « Réduire les animations » est actif.
    func pulseTransition(_ transition: AnyTransition) -> some View {
        modifier(PulseTransitionModifier(transition: transition))
    }

    /// Fait rouler les chiffres quand `value` change, sauf quand « Réduire les animations » est actif.
    func pulseNumericTransition(value: Double) -> some View {
        modifier(PulseNumericTransitionModifier(value: value))
    }
}
