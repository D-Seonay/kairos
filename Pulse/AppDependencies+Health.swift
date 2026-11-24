import Foundation
import PulseDomain
import PulseServices

extension AppDependencies {
    /// L'écriture des séances dans Apple Santé ; `nil` sans écrivain dans le câblage. Elle relit les pesées saisies pour la masse
    /// du jour.
    static func healthExporter(_ wiring: Wiring, _ workouts: any WorkoutRepository, _ profiles: any ProfileRepository,
                               _ measurements: any BodyMeasurementRepository) -> HealthWorkoutExporter? {
        wiring.healthWriter.map {
            HealthWorkoutExporter(writer: $0, workouts: workouts, profiles: profiles, measurements: measurements,
                                  calendar: wiring.calendar)
        }
    }
}
