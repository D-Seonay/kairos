import Foundation
import PulseDomain
import PulseServices
import Testing

struct SleepPlanTests {
    private let calendar = TestClock.calendar

    private func profile(goal: Int? = 480, weekday: Int? = 420, weekend: Int? = 540, lead: Int? = 30) -> UserProfile {
        UserProfile(sleepGoalMinutes: goal, weekdayWakeMinutes: weekday, weekendWakeMinutes: weekend,
                    bedtimeReminderEnabled: true, bedtimeReminderLeadMinutes: lead)
    }

    private func plan(_ profile: UserProfile? = nil, wokeUp: [Date] = []) -> SleepPlan {
        SleepPlan(profile: profile ?? self.profile(), wokeUp: wokeUp, calendar: calendar)
    }

    @Test func weekdayBedtimeIsWakeMinusGoalMinusFallAsleep() {
        #expect(plan().bedtimeMinutes(weekend: false) == 1365)
    }

    @Test func weekendBedtimeCrossesMidnight() {
        #expect(plan().bedtimeMinutes(weekend: true) == 45)
    }

    @Test func fridayEveningFollowsTheWeekendWake() {
        let friday = TestClock.date("2026-11-20T12:00")
        #expect(plan().bedtime(onEvening: friday, calendar: calendar) == TestClock.date("2026-11-21T00:45"))
        #expect(plan().reminderDate(onEvening: friday, calendar: calendar) == TestClock.date("2026-11-21T00:15"))
    }

    @Test func sundayEveningFollowsTheWeekdayWake() {
        let sunday = TestClock.date("2026-11-22T12:00")
        #expect(plan().bedtime(onEvening: sunday, calendar: calendar) == TestClock.date("2026-11-22T22:45"))
        #expect(plan().reminderDate(onEvening: sunday, calendar: calendar) == TestClock.date("2026-11-22T22:15"))
        #expect(SleepPlan.wakesOnWeekend(afterEvening: TestClock.date("2026-11-21T20:00"), calendar: calendar))
        #expect(!SleepPlan.wakesOnWeekend(afterEvening: sunday, calendar: calendar))
    }

    @Test func reminderOutsideTheEveningIsDropped() {
        let wednesday = TestClock.date("2026-11-18T12:00")
        #expect(plan(profile(goal: 360, weekday: 720)).reminderDate(onEvening: wednesday, calendar: calendar) == nil)
        #expect(plan(profile(goal: 600, weekday: 240)).reminderDate(onEvening: wednesday, calendar: calendar) == nil)
    }

    @Test func reminderBoundsAreInclusive() {
        let wednesday = TestClock.date("2026-11-18T12:00")
        // Coucher 18:30, rappel 18:00 pile.
        let early = plan(profile(goal: 600, weekday: 285)).reminderDate(onEvening: wednesday, calendar: calendar)
        #expect(early == TestClock.date("2026-11-18T18:00"))
        // Coucher 03:30, rappel 03:00 pile.
        let late = plan(profile(goal: 360, weekday: 585)).reminderDate(onEvening: wednesday, calendar: calendar)
        #expect(late == TestClock.date("2026-11-19T03:00"))
    }

    @Test func chosenWakeWinsOverTheHabitualOne() {
        let wakes = ["2026-11-16T06:00", "2026-11-17T06:00", "2026-11-18T06:00", "2026-11-19T06:00", "2026-11-20T06:00"]
            .map { TestClock.date($0) }
        let chosen = plan(wokeUp: wakes)
        #expect(chosen.habitualWeekdayWake == 360)
        #expect(chosen.wakeMinutes(weekend: false) == 420)
        let none = plan(profile(weekday: nil, weekend: nil), wokeUp: wakes)
        #expect(none.wakeMinutes(weekend: false) == 360)
    }

    @Test func noWakeGivesNoBedtime() {
        let empty = plan(profile(weekday: nil, weekend: nil))
        let day = TestClock.date("2026-11-18T12:00")
        #expect(empty.bedtimeMinutes(weekend: false) == nil)
        #expect(empty.bedtime(onEvening: day, calendar: calendar) == nil)
        #expect(empty.reminderDate(onEvening: day, calendar: calendar) == nil)
    }

    @Test func outOfRangeGoalIsClamped() {
        #expect(plan(profile(goal: 2000)).goalMinutes == 600)
    }

    @Test func missingLeadDefaultsToThirtyMinutes() {
        let sunday = TestClock.date("2026-11-22T12:00")
        let plan = plan(profile(lead: nil))
        #expect(plan.leadMinutes == 30)
        #expect(plan.reminderDate(onEvening: sunday, calendar: calendar) == TestClock.date("2026-11-22T22:15"))
    }

    @Test func clockTextPadsHours() {
        #expect(SleepPlan.clockText(minutes: 1365) == "22:45")
        #expect(SleepPlan.clockText(minutes: 45) == "00:45")
        #expect(SleepPlan.clockText(minutes: 420) == "07:00")
    }

    @Test func settingsChangedSeesEachOfTheFiveFields() {
        let base = profile()
        var goal = base; goal.sleepGoalMinutes = 450
        var weekday = base; weekday.weekdayWakeMinutes = 400
        var weekend = base; weekend.weekendWakeMinutes = 600
        var enabled = base; enabled.bedtimeReminderEnabled = false
        var lead = base; lead.bedtimeReminderLeadMinutes = 45
        for changed in [goal, weekday, weekend, enabled, lead] {
            #expect(SleepPlan.settingsChanged(from: base, to: changed))
        }
        var theme = base; theme.theme = .amethyst
        #expect(!SleepPlan.settingsChanged(from: base, to: theme))
    }
}
