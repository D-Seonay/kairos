#if DEBUG
import Foundation
import PulseContent
import PulseDomain
import PulseServices
import SwiftUI

/// Les doublures des aperçus de la bibliothèque, de la fiche et du formulaire : trois séances de développé couché et un exercice
/// perso, sur l'horloge fixe de `TrainPreviewSupport`.
@MainActor
enum ExercisePreviewSupport {
    static let bench = ExerciseReference.content(id: "bench-press-barbell")

    /// Le profil, les trois séances de développé couché, leurs records et un exercice perso, le tout enregistré.
    static func environment(painAreas: [PainArea] = []) async -> TrainEnvironment {
        let now = TrainPreviewSupport.date(day: 2, hour: 9)
        let environment = TrainPreviewSupport.environment(
            profiles: InMemoryProfileRepository(), programs: InMemoryProgramRepository(),
            recovery: InMemoryRecoveryRepository(calendar: TrainPreviewSupport.calendar), now: now)
        try? await environment.profiles.save(UserProfile(firstName: "Mathéo", painAreas: painAreas, onboardingCompletedAt: now,
                                                         createdAt: now, updatedAt: now))
        for (month, day, kilos, reps) in [(10, 2, 60.0, 10), (10, 12, 70, 5), (10, 26, 72.5, 5)] {
            try? await environment.workouts.save(session(month: month, day: day, kilos: kilos, reps: reps))
        }
        try? await environment.userExercises.save(UserExercise(
            name: "Zercher squat", primaryMuscle: .quads, secondaryMuscles: [.glutes, .lowerBack], equipment: .barbell,
            pattern: .squat, region: .lower, isUnilateral: false, defaultIncrementKg: 5, defaultRestSeconds: 180,
            isCompound: true, createdAt: now, updatedAt: now))
        _ = try? await environment.records.recomputeAll()
        return environment
    }

    private static func session(month: Int, day: Int, kilos: Double, reps: Int) -> WorkoutSession {
        let components = DateComponents(calendar: TrainPreviewSupport.calendar, timeZone: TrainPreviewSupport.calendar.timeZone,
                                        year: 2026, month: month, day: day, hour: 18)
        let date = components.date ?? Date(timeIntervalSinceReferenceDate: 0)
        let sets = (0..<3).map { index in
            WorkoutSet(order: index, exercise: bench, exerciseName: "Développé couché à la barre", setType: .working,
                       actualWeightKg: kilos, actualReps: reps, rpe: 8, completedAt: date)
        }
        return WorkoutSession(startedAt: date, endedAt: date.addingTimeInterval(3_600), kind: .strength, source: .pulse,
                              status: .completed, title: "Push", tonnageKg: kilos * Double(reps) * 3, sets: sets,
                              createdAt: date, updatedAt: date)
    }
}

/// Prépare l'environnement de l'aperçu puis affiche l'écran que `content` construit dessus.
struct ExercisePreviewHost<Content: View>: View {
    var painAreas: [PainArea] = []
    @ViewBuilder let content: (TrainEnvironment) -> Content
    @State private var environment: TrainEnvironment?

    var body: some View {
        Group {
            if let environment {
                NavigationStack { content(environment) }
            } else {
                ProgressView()
            }
        }
        .task { environment = await ExercisePreviewSupport.environment(painAreas: painAreas) }
        .preferredColorScheme(.dark)
    }
}

#Preview("Bibliothèque") {
    ExercisePreviewHost { LibraryView(model: LibraryModel(environment: $0, mode: .browse)) }
}

#Preview("Bibliothèque, choix multiple") {
    ExercisePreviewHost { LibraryView(model: LibraryModel(environment: $0, mode: .pick(multiple: true))) }
}

#Preview("Fiche, développé couché") {
    ExercisePreviewHost { ExerciseSheetView(model: ExerciseSheetModel(environment: $0, reference: ExercisePreviewSupport.bench)) }
}

#Preview("Fiche, dips et épaules signalées") {
    ExercisePreviewHost(painAreas: [.shoulders]) {
        ExerciseSheetView(model: ExerciseSheetModel(environment: $0, reference: .content(id: "dips")))
    }
}

#Preview("Fiche, sans historique") {
    ExercisePreviewHost { ExerciseSheetView(model: ExerciseSheetModel(environment: $0, reference: .content(id: "plank"))) }
}

#Preview("Nouvel exercice") {
    ExercisePreviewHost { CustomExerciseForm(model: CustomExerciseModel(environment: $0, draft: nil, editing: nil)) }
}

#Preview("Exercice depuis l'import") {
    ExercisePreviewHost {
        CustomExerciseForm(model: CustomExerciseModel(environment: $0, draft: HevyNameGuesser.draft(for: "Shrug (Haltère)"),
                                                      editing: nil))
    }
}
#endif
