import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// Les lignes de la séance à suivre en salle : Push de PPL 3, ajusté en fatigue modérée.
struct SessionPlanLineTests {
    private let library = ContentLibrary.bundled

    private func push() throws -> RoutineDay {
        let now = TodayClock.date("2026-11-02T08:00")
        let template = try #require(library.programTemplate(id: "ppl-3"))
        let program = ProgramAdopter(library: library).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
        return try #require(program.days.first { $0.name == "Push" })
    }

    @Test func linesShowAdjustedSetsAndRest() throws {
        let now = TodayClock.date("2026-11-02T08:00")
        let fatigue = DailyRecovery(day: now, score: 50, category: .moderateFatigue, isEstimated: false, calibration: .ready,
                                    createdAt: now, updatedAt: now)
        let adjusted = try #require(TodaySession(plannedDay: .strength(try push()), recovery: fatigue).activeDay)
        let lines = SessionPlanLine.lines(for: adjusted, library: library)
        #expect(lines.count == 6)
        let bench = try #require(library.exercise(id: "bench-press-barbell")).name.fr
        #expect(lines.first == SessionPlanLine(name: bench, prescription: "3 × 6–10", rest: "repos 2 min 45"))
    }

    /// Le triceps à la poulie et le curl des poignets forment un super set : on enchaîne le premier, on se repose après le second.
    @Test func supersetMembersAreFlagged() throws {
        let lines = SessionPlanLine.lines(for: try push(), library: library)
        #expect(lines[3].rest == "super set, sans repos")
        #expect(lines[4].rest == "super set · repos 1 min")
        #expect(lines[5].rest == "repos 1 min")
    }

    @Test func userExerciseAndFixedRepsAreReadable() {
        let day = RoutineDay(order: 0, name: "Perso", kind: .strength, exercises: [
            RoutineExercise(order: 0, exercise: .user(id: UUID()), sets: 4, repsMin: 8, repsMax: 8, targetRPE: 8, restSeconds: 45)
        ])
        #expect(SessionPlanLine.lines(for: day, library: library)
            == [SessionPlanLine(name: "Exercice personnel", prescription: "4 × 8", rest: "repos 45 s")])
    }

    @Test func linesFollowTheExerciseOrder() {
        let day = RoutineDay(order: 0, name: "Perso", kind: .strength, exercises: [
            RoutineExercise(order: 1, exercise: .content(id: "crunch-machine"), sets: 2, repsMin: 10, repsMax: 12, targetRPE: 8,
                            restSeconds: 60),
            RoutineExercise(order: 0, exercise: .content(id: "bench-press-barbell"), sets: 3, repsMin: 6, repsMax: 10, targetRPE: 8,
                            restSeconds: 120)
        ])
        let names = SessionPlanLine.lines(for: day, library: library).map(\.name)
        #expect(names == ["bench-press-barbell", "crunch-machine"].map { library.exercise(id: $0)?.name.fr ?? "" })
    }
}
