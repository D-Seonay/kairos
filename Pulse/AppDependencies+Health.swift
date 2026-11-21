import Foundation
import PulseDomain
import PulseServices

extension AppDependencies {
    /// L'écriture des séances dans Apple Santé ; `nil` sans écrivain. Elle relit les pesées saisies pour la masse du jour.
    static func healthExporter(_ writer: (any WorkoutHealthWriting)?, _ workouts: any WorkoutRepository,
                               _ profiles: any ProfileRepository, _ measurements: any BodyMeasurementRepository,
                               _ calendar: Calendar) -> HealthWorkoutExporter? {
        writer.map {
            HealthWorkoutExporter(writer: $0, workouts: workouts, profiles: profiles, measurements: measurements, calendar: calendar)
        }
    }
}
