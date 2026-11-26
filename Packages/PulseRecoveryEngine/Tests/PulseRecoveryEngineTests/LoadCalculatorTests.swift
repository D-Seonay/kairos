import Foundation
@testable import PulseRecoveryEngine
import Testing

@Suite struct LoadCalculatorTests {
    let calculator = LoadCalculator(calendar: TestCalendar.paris)
    let day = TestCalendar.day(2026, 11, 28)
    let start = TestCalendar.day(2026, 11, 1)

    /// Une séance de 60 min à RPE 7 (charge 420) chaque semaine, offsets 0, 7, 14, 21.
    var weeklySessions: [LoadSession] {
        [0, 7, 14, 21].map { LoadSession(date: TestCalendar.shift(day, by: -$0), minutes: 60, rpe: 7) }
    }

    @Test func steadyLoadIsOptimal() {
        let r = calculator.acwr(sessions: weeklySessions, asOf: day, historyStart: start)
        #expect(r?.acute == 420)
        #expect(r?.chronic == 420)
        #expect(r?.ratio == 1)
        #expect(r?.zone == .optimal)
    }

    @Test func spikeIsRisk() throws {
        let sessions = weeklySessions + [LoadSession(date: TestCalendar.date(2026, 11, 28, 18, 0), minutes: 60, rpe: 8)]
        let r = try #require(calculator.acwr(sessions: sessions, asOf: day, historyStart: start))
        #expect(r.acute == 900)
        #expect(r.chronic == 540)
        #expect(abs(r.ratio - 1.6667) < 1e-4)
        #expect(r.zone == .risk)
    }

    @Test func needsTwentyEightDaysOfHistory() {
        let lateStart = TestCalendar.shift(day, by: -20)
        #expect(calculator.acwr(sessions: weeklySessions, asOf: day, historyStart: lateStart) == nil)
    }

    @Test(arguments: [
        (0.79, ACWRZone.undertraining), (0.8, .optimal), (1.3, .optimal),
        (1.31, .elevated), (1.49, .elevated), (1.5, .risk)
    ])
    func zoneBoundaries(ratio: Double, expected: ACWRZone) {
        #expect(ACWRZone(ratio: ratio) == expected)
    }

    @Test func noChronicLoadReturnsNil() {
        #expect(calculator.acwr(sessions: [], asOf: day, historyStart: start) == nil)
    }

    @Test func sessionLoadIsMinutesTimesRPE() {
        #expect(LoadSession(date: day, minutes: 45, rpe: 6).load == 270)
    }

    private func sessions(daysAgo offsets: [Int], minutes: Double = 60) -> [LoadSession] {
        offsets.map { LoadSession(date: TestCalendar.shift(day, by: -$0), minutes: minutes, rpe: 7) }
    }

    /// La base se lit sur les deux semaines d'avant la semaine aiguë, des jours −20 à −7 : il y faut 3 séances.
    @Test func trainingBaseNeedsThreeSessionsBeforeTheAcuteWeek() {
        #expect(LoadCalculator.minimumBaseSessions == 3)
        #expect(calculator.hasTrainingBase(sessions: sessions(daysAgo: [7, 14, 20]), asOf: day))
        #expect(!calculator.hasTrainingBase(sessions: sessions(daysAgo: [7, 20]), asOf: day))
        #expect(!calculator.hasTrainingBase(sessions: sessions(daysAgo: [7, 14, 21]), asOf: day), "Le jour −21 est hors de la base")
        #expect(!calculator.hasTrainingBase(sessions: [], asOf: day))
    }

    /// Une pause puis une semaine normale : la semaine aiguë ne fait pas une base, les séances d'avant la pause non plus.
    @Test func aComebackWeekIsNotATrainingBase() {
        let comeback = sessions(daysAgo: [0, 1, 3, 5, 6])
        #expect(!calculator.hasTrainingBase(sessions: comeback + sessions(daysAgo: [28, 30, 35, 40]), asOf: day))
        // Deux semaines de pause après une semaine pleine : le ratio vaut 2, et ce n'est toujours pas une surcharge.
        #expect(!calculator.hasTrainingBase(sessions: comeback + sessions(daysAgo: [21, 23, 25, 27]), asOf: day))
        #expect(!calculator.hasTrainingBase(sessions: comeback + sessions(daysAgo: [8, 28]), asOf: day))
        #expect(calculator.hasTrainingBase(sessions: comeback + sessions(daysAgo: [8, 15, 20]), asOf: day))
    }

    /// Une séance sans charge (durée nulle) ne porte rien : elle ne compte pas dans la base.
    @Test func sessionsWithoutLoadDoNotMakeABase() {
        let empty = sessions(daysAgo: [10], minutes: 0)
        #expect(!calculator.hasTrainingBase(sessions: sessions(daysAgo: [8, 20]) + empty, asOf: day))
        let lateInTheDay = [LoadSession(date: TestCalendar.date(2026, 11, 21, 21, 30), minutes: 60, rpe: 7),
                            LoadSession(date: TestCalendar.date(2026, 11, 8, 6, 0), minutes: 60, rpe: 7)]
        #expect(calculator.hasTrainingBase(sessions: sessions(daysAgo: [14]) + lateInTheDay, asOf: day),
                "Les bornes se comptent en jours calendaires : le 21 au soir est le jour −7, le 8 au matin le jour −20")
    }
}
