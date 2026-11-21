import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct LoadStatsTests {
    private let now = TestClock.date("2026-11-20T12:00")
    private var calendar: Calendar { TestClock.calendar }

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
    }

    private func session(daysAgo: Int, kind: SessionKind = .strength, minutes: Double = 60, rpe: Double = 7,
                         tonnage: Double = 0, distance: Double? = nil, status: SessionStatus = .completed) -> WorkoutSession {
        let start = day(daysAgo).addingTimeInterval(7 * 3_600)
        let isStrength = kind == .strength
        return WorkoutSession(
            startedAt: start, endedAt: start.addingTimeInterval(minutes * 60), kind: kind, source: isStrength ? .pulse : .appleHealth,
            status: status, title: "Séance", overallRPE: isStrength ? rpe : nil, tonnageKg: tonnage, durationMinutes: minutes,
            distanceMeters: distance, estimatedRPE: isStrength ? nil : rpe, createdAt: start, updatedAt: start)
    }

    /// Cinq semaines : une séance de musculation (60 min, RPE 7) tous les deux jours, une course de 45 min (RPE 6) il y a 3 jours
    /// et un vélo de 60 min (RPE 8) il y a 12 jours.
    private var fiveWeeks: [WorkoutSession] {
        let strength = stride(from: 0, through: 34, by: 2).map { session(daysAgo: $0, tonnage: 1_000) }
        return strength + [
            session(daysAgo: 3, kind: .run, minutes: 45, rpe: 6, distance: 8_000),
            session(daysAgo: 12, kind: .ride, minutes: 60, rpe: 8, distance: 20_000)
        ]
    }

    /// Une séance par jour sur les `days` derniers jours, jour courant compris : ratio 1 dès le 28e jour.
    private func daily(days: Int, minutes: Double = 60, rpe: Double = 5, except skipped: Range<Int> = 0..<0) -> [WorkoutSession] {
        (0..<days).filter { !skipped.contains($0) }.map { session(daysAgo: $0, minutes: minutes, rpe: rpe) }
    }

    private func stats(_ sessions: [WorkoutSession], historyDays: Int? = nil, period: StatsPeriod = .month,
                       deloadUntil: Date? = nil) -> LoadStats {
        let onboarding = historyDays.map { day($0 - 1) }
        return LoadStats.make(sessions: sessions, onboardingCompletedAt: onboarding, deloadUntil: deloadUntil, period: period,
                              now: now, calendar: calendar)
    }

    @Test func todayMatchesTrainingLoad() {
        let sessions = fiveWeeks
        let result = stats(sessions, historyDays: 40)
        let expected = TrainingLoad.acwr(sessions: sessions, onboardingCompletedAt: day(39), now: now, calendar: calendar)
        #expect(result.today != nil)
        #expect(result.today == expected)
    }

    @Test func ratioPointsOnePerDayFromDay28() {
        let result = stats(daily(days: 35), historyDays: 35, period: .month)
        #expect(result.ratioPoints.count == 8)
        #expect(result.ratioPoints.first?.date == day(7))
        #expect(result.ratioPoints.last?.date == day(0))
        #expect(result.daysUntilRatio == nil)
    }

    @Test func daysUntilRatioCountsDown() {
        let result = stats(daily(days: 10), historyDays: 10)
        #expect(result.ratioPoints.isEmpty)
        #expect(result.today == nil)
        #expect(result.daysUntilRatio == 18)
    }

    @Test func yearPointsAreWeekly() {
        let result = stats(daily(days: 60), historyDays: 60, period: .year)
        #expect(!result.ratioPoints.isEmpty)
        #expect(result.ratioPoints.allSatisfy { calendar.component(.weekday, from: $0.date) == 1 })
        let gaps = zip(result.ratioPoints, result.ratioPoints.dropFirst()).map {
            calendar.dateComponents([.day], from: $0.date, to: $1.date).day
        }
        #expect(gaps.allSatisfy { $0 == 7 })
        #expect(result.ratioPoints.count == 4)
    }

    @Test func acuteWeekBeforeIsTheAcuteLoadOneWeekEarlier() throws {
        let result = stats(daily(days: 60), historyDays: 60)
        #expect(result.acuteWeekBefore == 2_100)
        let young = stats(daily(days: 30), historyDays: 30)
        #expect(young.today != nil)
        #expect(young.acuteWeekBefore == nil)
    }

    @Test func rideIsCappedAtFive() throws {
        let result = stats(fiveWeeks, historyDays: 40, period: .month)
        let rideWeek = WeekSchedule.weekStart(of: day(12), calendar: calendar)
        let bar = try #require(result.bars.first { $0.start == rideWeek })
        #expect(bar.ride == 60 * 5)
        #expect(bar.run == 0)
    }

    @Test func barsCoverTheWholePeriodInOrder() {
        let month = stats(fiveWeeks, historyDays: 40, period: .month)
        #expect(month.bars.map(\.start) == month.bars.map(\.start).sorted())
        #expect(month.bars.first?.start == WeekSchedule.weekStart(of: day(29), calendar: calendar))
        #expect(month.bars.last?.start == WeekSchedule.weekStart(of: day(0), calendar: calendar))
        #expect(month.bars.count == 5)
        let week = stats(fiveWeeks, historyDays: 40, period: .week)
        #expect(week.bars.map(\.start) == (0..<7).reversed().map { day($0) })
        let emptyDay = week.bars.first { $0.start == day(1) }
        #expect(emptyDay == LoadBar(start: day(1), strength: 0, run: 0, ride: 0))
    }

    @Test func totals() {
        let result = stats(fiveWeeks, historyDays: 40, period: .month)
        // Les séances de musculation des jours 0, 2, …, 28 sont dans les 30 jours.
        let strengthCount = 15
        let strengthLoad = Double(strengthCount) * 60 * 7
        let total = strengthLoad + 45 * 6 + 60 * 5
        #expect(result.totals.tonnageKg == Double(strengthCount) * 1_000)
        #expect(result.totals.runMeters == 8_000)
        #expect(result.totals.rideMeters == 20_000)
        #expect(result.totals.minutes == Double(strengthCount) * 60 + 45 + 60)
        #expect(result.totals.sessions == strengthCount + 2)
        #expect(result.totals.strengthShare == strengthLoad / total)
        #expect(result.totals.strengthLoad == strengthLoad)
        #expect(result.totals.runLoad == 45 * 6)
        #expect(result.totals.rideLoad == 60 * 5)
        #expect(result.totals.totalLoad == total)
    }

    /// Une séance comptée sans durée calculable garde son tonnage, sa distance et sa place dans le nombre de séances ; seuls les
    /// minutes et la charge l'ignorent.
    @Test func sessionsWithoutDurationStillCount() {
        func noDuration(daysAgo: Int, kind: SessionKind, status: SessionStatus, tonnage: Double, distance: Double?) -> WorkoutSession {
            let start = day(daysAgo).addingTimeInterval(7 * 3_600)
            return WorkoutSession(startedAt: start, endedAt: nil, kind: kind, source: .pulse, status: status, title: "Séance",
                                  tonnageKg: tonnage, distanceMeters: distance, createdAt: start, updatedAt: start)
        }
        let sessions = [
            session(daysAgo: 5, tonnage: 500),
            noDuration(daysAgo: 4, kind: .strength, status: .completed, tonnage: 700, distance: nil),
            noDuration(daysAgo: 2, kind: .strength, status: .abandoned, tonnage: 300, distance: nil),
            noDuration(daysAgo: 1, kind: .run, status: .completed, tonnage: 0, distance: 5_000)
        ]
        let result = stats(sessions, historyDays: 40, period: .month)
        #expect(result.totals.sessions == 4)
        #expect(result.totals.tonnageKg == 1_500)
        #expect(result.totals.runMeters == 5_000)
        #expect(result.totals.minutes == 60)
        #expect(result.totals.strengthShare == 1)
    }

    /// La première semaine d'une période qui commence en milieu de semaine compte ses séances d'avant la période.
    @Test func firstWeeklyBarCoversItsWholeWeek() throws {
        // Le mois commence le jeudi 22 octobre : la barre du lundi 19 octobre reprend la séance du 20, hors période.
        let monday = TestClock.date("2026-10-19T00:00")
        let before = session(daysAgo: 31)
        #expect(before.startedAt == day(31).addingTimeInterval(7 * 3_600))
        #expect(calendar.component(.weekday, from: before.startedAt) == 3)
        let result = stats([before], historyDays: 40, period: .month)
        let first = try #require(result.bars.first)
        #expect(first.start == monday)
        #expect(first.strength == 60 * 7)
        #expect(result.totals.sessions == 0)
        // Les totaux de charge, eux, ignorent la séance d'avant la période.
        #expect(result.totals.totalLoad == 0)
    }

    @Test func totalsWithoutAnySessionAreEmpty() {
        let result = stats([], historyDays: nil)
        #expect(result.totals == LoadTotals(tonnageKg: 0, runMeters: 0, rideMeters: 0, minutes: 0, sessions: 0, strengthShare: nil))
        #expect(result.bars.allSatisfy { $0.strength == 0 && $0.run == 0 && $0.ride == 0 })
        #expect(result.verdict == nil)
    }

    @Test func deloadWinsOverEverything() {
        let until = day(0).addingTimeInterval(2 * 86_400)
        let result = stats(daily(days: 60), historyDays: 60, deloadUntil: until)
        #expect(result.verdict == .deload(until: until))
        #expect(stats([], deloadUntil: day(0)).verdict == .deload(until: day(0)))
    }

    @Test func endedDeloadDoesNotCount() {
        let result = stats(daily(days: 60), historyDays: 60, deloadUntil: day(1))
        #expect(result.verdict == .optimal(weeks: 4))
    }

    @Test func optimalRatioForTwoWeeks() {
        // Ratio 1 dès le 28e jour d'historique : 42 jours d'historique donnent 15 jours d'affilée dans la zone.
        #expect(stats(daily(days: 42), historyDays: 42).verdict == .optimal(weeks: 2))
    }

    @Test func optimalForLessThanAWeekIsSteady() {
        #expect(stats(daily(days: 30), historyDays: 30).verdict == .steady)
    }

    @Test func elevatedForThreeDays() {
        // Quatre grosses journées : la première fait monter le ratio sans le sortir de la zone, les trois suivantes le dépassent.
        let high = (0..<4).map { session(daysAgo: $0, minutes: 120, rpe: 10) }
        let result = stats(daily(days: 60, except: 0..<4) + high, historyDays: 60)
        #expect(result.verdict == .elevated(days: 3))
    }

    @Test func lowWhenLoadDrops() {
        let result = stats(daily(days: 60, except: 0..<7), historyDays: 60)
        #expect(result.verdict == .low)
    }

    @Test func noVerdictWithoutRatio() {
        #expect(stats(daily(days: 10), historyDays: 10).verdict == nil)
    }

    @Test func inProgressSessionsDoNotCount() {
        let running = [session(daysAgo: 1, status: .inProgress)]
        let result = stats(running, historyDays: 40)
        #expect(result.totals.sessions == 0)
        #expect(result.today == nil)
    }
}
