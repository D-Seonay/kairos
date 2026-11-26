import Foundation
import PulseDomain
import PulseServices
import Testing

struct WeekLayoutArrangerTests {
    private let sessionA = UUID()
    private let sessionB = UUID()
    private let sessionC = UUID()

    private var week: [UUID?] { [sessionA, nil, sessionB, nil, sessionC, nil, nil] }

    @Test func withoutRestDaysTheWeekIsUnchanged() {
        #expect(WeekLayoutArranger.arrange(week, restWeekdays: []) == week)
    }

    @Test func restDaysSlideSessionsForward() {
        let arranged = WeekLayoutArranger.arrange(week, restWeekdays: [.wednesday, .sunday])
        #expect(arranged == [sessionA, nil, nil, sessionB, sessionC, nil, nil])
    }

    @Test func slidingWrapsAroundTheWeek() {
        let arranged = WeekLayoutArranger.arrange(week, restWeekdays: [.friday, .saturday, .sunday])
        #expect(arranged == [sessionA, sessionC, sessionB, nil, nil, nil, nil])
    }

    @Test func sessionsWithoutRoomLeaveTheWeek() {
        let sessions = (0..<6).map { _ in UUID() }
        let layout: [UUID?] = sessions.map { $0 } + [nil]
        let arranged = WeekLayoutArranger.arrange(layout, restWeekdays: [.saturday, .sunday])
        #expect(arranged.count == 7)
        #expect(arranged.compactMap { $0 }.count == 5)
        #expect(Array(arranged.prefix(5)) == sessions.prefix(5).map { $0 })
        #expect(!arranged.contains(sessions[5]))
    }
}

struct WeekShorteningTests {
    private func day(_ name: String, order: Int, kind: RoutineDayKind = .strength) -> RoutineDay {
        RoutineDay(order: order, name: name, kind: kind, runType: kind == .run ? .easy : nil)
    }

    private func names(_ layout: [UUID?], in program: Program) -> [String?] {
        layout.map { id in id.flatMap { id in program.days.first { $0.id == id }?.name } }
    }

    @Test func onlyTheFirstStrengthRoutinesStayInTheWeek() {
        let (first, second, third, run) = (day("A", order: 0), day("B", order: 1), day("C", order: 2), day("Footing", order: 3, kind: .run))
        // La semaine ne suit pas l'ordre du programme : ce sont les premières routines du programme qui restent.
        let program = Program(name: "Semaine", sessionsPerWeek: 4, weekLayout: [third.id, nil, first.id, run.id, second.id, nil, nil],
                              days: [first, second, third, run], createdAt: .t0, updatedAt: .t0)
        #expect(names(WeekLayoutArranger.keeping(strengthDays: 2, of: program), in: program) == [nil, nil, "A", "Footing", "B", nil, nil])
        #expect(names(WeekLayoutArranger.keeping(strengthDays: 0, of: program), in: program) == [nil, nil, nil, "Footing", nil, nil, nil])
        #expect(WeekLayoutArranger.keeping(strengthDays: 3, of: program) == program.weekLayout)
        #expect(WeekLayoutArranger.keeping(strengthDays: 9, of: program) == program.weekLayout)
    }

    @Test func aRoutinePlacedTwiceCountsOnce() {
        let (push, pull) = (day("Push", order: 0), day("Pull", order: 1))
        let program = Program(name: "Semaine", sessionsPerWeek: 3, weekLayout: [push.id, pull.id, nil, push.id, nil, nil, nil],
                              days: [push, pull], createdAt: .t0, updatedAt: .t0)
        #expect(names(WeekLayoutArranger.keeping(strengthDays: 1, of: program), in: program) == ["Push", nil, nil, "Push", nil, nil, nil])
    }
}
