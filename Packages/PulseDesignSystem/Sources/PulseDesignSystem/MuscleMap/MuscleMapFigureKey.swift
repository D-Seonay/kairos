import PulseDomain
import SwiftUI

public extension EnvironmentValues {
    /// La silhouette des cartes musculaires, injectée depuis le sexe du profil ; celle de femme par défaut.
    @Entry var muscleMapFigure: MuscleMapFigure = .female
}
