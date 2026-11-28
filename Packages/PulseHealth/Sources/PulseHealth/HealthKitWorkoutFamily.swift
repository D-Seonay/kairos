import HealthKit
import PulseDomain

/// La famille d'un type d'entraînement d'Apple Santé. La course et le vélo sont lus à part, en séances (`WorkoutSignal`) ; un type
/// inconnu ou « autre » compte comme de l'endurance.
public enum HealthKitWorkoutFamily {
    /// Les types lus à part, en séances : ils ne sont pas relus comme autres entraînements.
    public static let sessionTypes: [HKWorkoutActivityType] = [.running, .cycling]

    public static func family(of type: HKWorkoutActivityType) -> WorkoutFamily {
        switch type {
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio, .jumpRope, .kickboxing, .boxing, .martialArts,
             .cardioDance, .stairClimbing, .stairs, .stepTraining:
            .intermittent
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .climbing:
            .strength
        case .yoga, .pilates, .flexibility, .mindAndBody, .taiChi, .cooldown, .preparationAndRecovery, .barre:
            .mobility
        case .walking, .hiking:
            .walking
        default:
            sportsTypes.contains(type) ? .sports : .endurance
        }
    }

    /// Sports collectifs, de raquette, de combat et d'adresse.
    private static let sportsTypes: Set<HKWorkoutActivityType> = [
        .americanFootball, .australianFootball, .badminton, .baseball, .basketball, .cricket, .discSports, .fencing, .handball,
        .hockey, .lacrosse, .pickleball, .racquetball, .rugby, .soccer, .softball, .squash, .tableTennis, .tennis, .volleyball,
        .waterPolo, .wrestling, .gymnastics, .trackAndField, .socialDance, .golf, .bowling, .curling, .archery, .equestrianSports,
        .play
    ]
}
