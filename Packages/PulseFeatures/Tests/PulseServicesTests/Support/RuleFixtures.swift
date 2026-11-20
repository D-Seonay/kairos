import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Une semaine hybride : Push lundi, Pull mardi, jambes lourdes mercredi, fractionné jeudi, Push vendredi, repos le week-end
/// (le dimanche obligatoire) ; la semaine du lundi 16 novembre 2026.
enum RuleFixtures {
    static let created = TestClock.date("2026-10-01T08:00")
    static let directory = ExerciseDirectory(library: .bundled, userExercises: [])
    static let push = RoutineDay(order: 0, name: "Push", kind: .strength,
                                 exercises: [exercise("bench-press-barbell", sets: 4), exercise("lat-pulldown-machine", sets: 3)])
    static let pull = RoutineDay(order: 1, name: "Pull", kind: .strength, exercises: [exercise("lat-pulldown-cable", sets: 4)])
    static let legs = RoutineDay(order: 2, name: "Jambes lourdes", kind: .strength,
                                 exercises: [exercise("back-squat-barbell", sets: 4), exercise("leg-press-machine", sets: 3),
                                             exercise("romanian-deadlift-barbell", sets: 3), exercise("leg-press-calf-raise", sets: 3)])
    static let intervals = RoutineDay(order: 3, name: "Fractionné", kind: .run, runType: .intervals, runTargetMinutes: 40)
    static let programID = UUID()

    static func program(thursday: RoutineDay = intervals) -> Program {
        Program(id: programID, name: "Hybride", sessionsPerWeek: 5,
                weekLayout: [push.id, pull.id, legs.id, thursday.id, push.id, nil, nil],
                days: [push, pull, legs, thursday], createdAt: created, updatedAt: created)
    }

    static func exercise(_ id: String, sets: Int) -> RoutineExercise {
        RoutineExercise(order: 0, exercise: .content(id: id), sets: sets, repsMin: 6, repsMax: 10, targetRPE: 8, restSeconds: 120)
    }

    /// Une séance faite à `start` : des séries de travail de `exercises`, une par entrée.
    static func session(_ start: String, kind: SessionKind = .strength, exercises: [String] = ["bench-press-barbell"]) -> WorkoutSession {
        let date = TestClock.date(start)
        let sets = kind == .strength ? exercises.enumerated().map { index, id in
            WorkoutSet(order: index, exercise: .content(id: id), exerciseName: id, setType: .working, actualWeightKg: 60, actualReps: 8)
        } : []
        return WorkoutSession(startedAt: date, endedAt: date.addingTimeInterval(3_600), kind: kind, source: .pulse,
                              status: .completed, title: kind == .run ? "Course" : "Séance", durationMinutes: 60, sets: sets,
                              createdAt: date, updatedAt: date)
    }

    static func night(_ day: String, asleepMinutes: Int, deepMinutes: Int? = nil) -> NightSample {
        NightSample(day: TestClock.date("\(day)T00:00"), sdnnMs: nil, restingHeartRate: nil,
                    sleep: SleepSummary(asleepMinutes: asleepMinutes, deepMinutes: deepMinutes))
    }

    static func input(program: Program = program(), lines: [ScheduledDay] = [], sessions: [WorkoutSession] = [],
                      nights: [NightSample] = [], disabled: [AntiInterferenceRule] = [], rest: [Weekday] = [.sunday],
                      now: String = "2026-11-16T07:00") -> AntiInterferenceInput {
        let profile = UserProfile(restWeekdays: rest, antiInterferenceRulesDisabled: disabled, onboardingCompletedAt: created,
                                  activeProgramID: programID)
        return AntiInterferenceInput(program: program, profile: profile, lines: lines, sessions: sessions, nights: nights,
                                     directory: directory, calendar: TestClock.calendar, now: TestClock.date(now))
    }

    static func day(_ text: String) -> Date {
        TestClock.date("\(text)T00:00")
    }

    /// La ligne de la semaine datée qu'écrirait le service pour `line`.
    static func scheduled(_ line: RuleLine) -> ScheduledDay {
        let kind: ScheduledDayKind = switch line.routine?.kind {
        case .strength: .strength
        case .run: .run
        case nil: .rest
        }
        return ScheduledDay(date: line.date, programID: programID, routineDayID: line.routine?.id, title: line.routine?.name ?? "Repos",
                            kind: kind, status: .planned, movedFromDate: line.movedFromDate, moveReason: line.reason,
                            moveReasonText: line.text, createdAt: created, updatedAt: created)
    }
}
