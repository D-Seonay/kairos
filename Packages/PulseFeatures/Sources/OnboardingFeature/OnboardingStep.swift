/// Les six écrans du premier lancement, dans l'ordre. La valeur brute est ce que le magasin d'étape retient.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case health
    case profile
    case goals
    case program
    case calibration
}
