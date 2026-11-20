import Foundation
import PulseDomain

/// Une semaine type Push Pull Legs, course le jeudi, Push le vendredi, repos le week-end ; la semaine du lundi 16 novembre 2026.
enum PlanningFixtures {
    static let created = TestClock.date("2026-10-01T08:00")
    static let push = RoutineDay(order: 0, name: "Push", kind: .strength)
    static let pull = RoutineDay(order: 1, name: "Pull", kind: .strength)
    static let legs = RoutineDay(order: 2, name: "Legs", kind: .strength)
    static let run = RoutineDay(order: 3, name: "Endurance", kind: .run, runType: .easy, runTargetMinutes: 45)
    static let programID = UUID()

    static func program() -> Program {
        Program(id: programID, name: "PPL + course", sessionsPerWeek: 5,
                weekLayout: [push.id, pull.id, legs.id, run.id, push.id, nil, nil],
                days: [push, pull, legs, run], createdAt: created, updatedAt: created)
    }

    static func session(_ start: String, kind: SessionKind = .strength, status: SessionStatus = .completed,
                        source: SessionSource = .pulse, record: Bool = false) -> WorkoutSession {
        let date = TestClock.date(start)
        let sets = record ? [WorkoutSet(order: 0, exercise: .content(id: "bench-press"), exerciseName: "Développé couché",
                                        setType: .working, actualWeightKg: 80, actualReps: 5, isPersonalRecord: true)] : []
        return WorkoutSession(startedAt: date, endedAt: date.addingTimeInterval(3_600), kind: kind, source: source, status: status,
                              title: kind == .run ? "Course" : "Push", sets: sets, createdAt: date, updatedAt: date)
    }

    static func moved(_ routine: RoutineDay?, on day: String, from origin: String?) -> ScheduledDay {
        let kind: ScheduledDayKind = switch routine?.kind {
        case .strength: .strength
        case .run: .run
        case nil: .rest
        }
        return ScheduledDay(date: TestClock.date("\(day)T00:00"), programID: programID, routineDayID: routine?.id,
                            title: routine?.name ?? "Repos", kind: kind, status: .planned,
                            movedFromDate: origin.map { TestClock.date("\($0)T00:00") }, moveReason: .user,
                            createdAt: created, updatedAt: created)
    }
}
