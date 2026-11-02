#if DEBUG
import PulseDomain
import PulseServices
import SwiftUI

/// Des séances en mémoire pour les aperçus : une séance Hevy en septembre, une séance Hevy et une séance Pulse abandonnée en octobre.
@MainActor
enum HistoryPreviewSupport {
    static func environment(withSessions: Bool = true) async -> TrainEnvironment {
        let now = TrainPreviewSupport.date(day: 2, hour: 9)
        let environment = TrainPreviewSupport.environment(
            profiles: InMemoryProfileRepository(), programs: InMemoryProgramRepository(), recovery: InMemoryRecoveryRepository(
                calendar: TrainPreviewSupport.calendar), now: now)
        guard withSessions else { return environment }
        for session in sessions(now: now) {
            try? await environment.workouts.save(session)
        }
        _ = try? await environment.records.recomputeAll()
        return environment
    }

    static func sessions(now: Date) -> [WorkoutSession] {
        [session(Seed(month: 9, day: 28, title: "Pull", source: .hevy, status: .completed, weight: 60)),
         session(Seed(month: 10, day: 12, title: "Push", source: .hevy, status: .completed, weight: 80)),
         session(Seed(month: 10, day: 27, title: "Push", source: .pulse, status: .abandoned, weight: 82.5))]
    }

    static var pushID: UUID? {
        sessions(now: TrainPreviewSupport.date(day: 2, hour: 9)).first { $0.title == "Push" && $0.source == .hevy }?.id
    }

    private struct Seed {
        var month: Int
        var day: Int
        var title: String
        var source: SessionSource
        var status: SessionStatus
        var weight: Double
    }

    private static func session(_ seed: Seed) -> WorkoutSession {
        let (month, day, title, weight) = (seed.month, seed.day, seed.title, seed.weight)
        let components = DateComponents(calendar: TrainPreviewSupport.calendar, timeZone: TrainPreviewSupport.calendar.timeZone,
                                        year: 2026, month: month, day: day, hour: 18)
        let date = components.date ?? Date(timeIntervalSinceReferenceDate: 0)
        let bench = ExerciseReference.content(id: "bench-press-barbell")
        let fly = ExerciseReference.content(id: "dumbbell-fly")
        let sets = [WorkoutSet(order: 0, exercise: bench, exerciseName: "Développé couché", setType: .warmup, actualWeightKg: 40,
                               actualReps: 10, completedAt: date),
                    WorkoutSet(order: 1, exercise: bench, exerciseName: "Développé couché", setType: .working,
                               actualWeightKg: weight, actualReps: 5, rpe: 8, completedAt: date),
                    WorkoutSet(order: 2, exercise: bench, exerciseName: "Développé couché", setType: .working,
                               actualWeightKg: weight, actualReps: 4, rpe: 9, completedAt: date),
                    WorkoutSet(order: 3, exercise: fly, exerciseName: "Écartés", setType: .working, actualWeightKg: 15,
                               actualReps: 12, completedAt: date)]
        return WorkoutSession(
            id: stableID(month: month, day: day), startedAt: date, endedAt: date.addingTimeInterval(3_900), kind: .strength,
            source: seed.source, status: seed.status, title: title, note: "Bonne séance, épaule au calme.",
            exerciseNotes: [ExerciseNote(exercise: bench, text: "Pause d'une seconde en bas")], sets: sets, createdAt: date,
            updatedAt: date)
    }

    /// Un identifiant fixe par séance, pour que l'aperçu du détail retrouve la même séance.
    private static func stableID(month: Int, day: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", month * 100 + day)) ?? UUID()
    }
}

/// Affiche l'historique en mémoire dans une pile où toucher une séance ouvre son détail.
struct HistoryPreviewHost: View {
    var withSessions = true
    @State private var environment: TrainEnvironment?

    var body: some View {
        NavigationStack {
            if let environment {
                HistoryView(model: HistoryModel(environment: environment))
                    .navigationDestination(for: TrainDestination.self) { destination in
                        if case .session(let id) = destination {
                            SessionDetailView(model: SessionDetailModel(environment: environment, sessionID: id))
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .task { environment = await HistoryPreviewSupport.environment(withSessions: withSessions) }
        .preferredColorScheme(.dark)
    }
}

/// Affiche le détail de la séance Hevy « Push » de l'aperçu.
struct SessionDetailPreviewHost: View {
    @State private var model: SessionDetailModel?

    var body: some View {
        NavigationStack {
            if let model {
                SessionDetailView(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            let environment = await HistoryPreviewSupport.environment()
            model = SessionDetailModel(environment: environment, sessionID: HistoryPreviewSupport.pushID ?? UUID())
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Historique") {
    HistoryPreviewHost()
}

#Preview("Historique vide") {
    HistoryPreviewHost(withSessions: false)
}

#Preview("Détail d'une séance Hevy") {
    SessionDetailPreviewHost()
}
#endif
