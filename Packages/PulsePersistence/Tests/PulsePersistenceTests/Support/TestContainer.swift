import Foundation
import PulseDomain
import PulsePersistence
import SwiftData

enum TestContainer {
    static func make() throws -> ModelContainer {
        try PersistenceStack.makeContainer(mode: .inMemory)
    }
}

/// Dates fixes pour les tests.
enum Fixed {
    static let t0 = Date(timeIntervalSince1970: 1_794_700_000)
    static let t1 = Date(timeIntervalSince1970: 1_794_700_001)
    static let t2 = Date(timeIntervalSince1970: 1_794_700_002)
}

enum Sample {
    static func routineExercise(order: Int, exercise: ExerciseReference = .content(id: "bench-press-barbell"),
                                superset: Int? = nil) -> RoutineExercise {
        RoutineExercise(order: order, exercise: exercise, sets: 3, repsMin: 8, repsMax: 12, targetRPE: 8, restSeconds: 90,
                        supersetGroup: superset)
    }

    static func program(days: Int = 2) -> Program {
        let dayList = (0..<days).map { index in
            RoutineDay(order: index, name: "Jour \(index + 1)", kind: .strength, exercises: [
                routineExercise(order: 0), routineExercise(order: 1, exercise: .user(id: UUID()), superset: 1),
                routineExercise(order: 2, superset: 1)
            ])
        }
        return Program(name: "Programme", templateID: "ppl-3", sessionsPerWeek: days,
                       weekLayout: [dayList.first?.id, nil, dayList.last?.id, nil, nil, nil, nil], days: dayList,
                       createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func set(order: Int, exercise: ExerciseReference = .content(id: "bench-press-barbell"), type: SetType = .working) -> WorkoutSet {
        WorkoutSet(order: order, exercise: exercise, exerciseName: "Développé couché", setType: type, supersetGroup: order == 2 ? 1 : nil,
                   plannedWeightKg: 80, plannedReps: 8, actualWeightKg: 80, actualReps: order == 3 ? 3 : 8, rpe: 8, restSeconds: 120,
                   completedAt: Fixed.t1, isPersonalRecord: order == 1)
    }

    static func session(startedAt: Date = Fixed.t0, status: SessionStatus = .completed, sets: Int = 9) -> WorkoutSession {
        var all = (1...sets).map { set(order: $0) }
        if !all.isEmpty {
            all[0].setType = .warmup
            all[all.count - 1].replacedExercise = .content(id: "chest-press-machine")
            all[all.count - 1].replacementReason = .machineBusy
        }
        return WorkoutSession(startedAt: startedAt, endedAt: startedAt.addingTimeInterval(3_600), kind: .strength, source: .pulse,
                              status: status, programID: UUID(), routineDayID: UUID(), title: "Push",
                              appliedAdjustments: [SessionAdjustment(kind: .volume, reason: "Fatigue modérée", value: -0.2),
                                                   SessionAdjustment(kind: .rest, reason: "Repos +45 s", value: 45)],
                              refusedAdjustments: [SessionAdjustment(kind: .rpeCap, reason: "Plafond 7,5", value: 7.5)],
                              overallRPE: 8, note: "Dos ok, \"lourd\" aujourd'hui", tonnageKg: 5_120, durationMinutes: 60,
                              sets: all, createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func scheduledDay(date: Date = Fixed.t0) -> ScheduledDay {
        ScheduledDay(date: date, programID: UUID(), routineDayID: UUID(), title: "Legs", kind: .strength, status: .planned,
                     movedFromDate: date.addingTimeInterval(-86_400), moveReason: .antiInterferenceAfterHeavyLegs,
                     moveReasonText: "Fractionné vendredi", validatedManually: false, sessionID: nil,
                     createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func userExercise(name: String = "Rowing machine du coin", archived: Bool = false) -> UserExercise {
        UserExercise(name: name, primaryMuscle: .lats, secondaryMuscles: [.biceps, .rearDelts], equipment: .machine,
                     pattern: .horizontalPull, region: .upper, isUnilateral: false, defaultIncrementKg: 2.5,
                     defaultRestSeconds: 90, isArchived: archived,
                     createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }
}
