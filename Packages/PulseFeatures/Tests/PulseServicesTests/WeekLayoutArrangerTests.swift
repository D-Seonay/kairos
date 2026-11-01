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
