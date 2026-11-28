import Foundation
import PulseDomain
import PulseServices
import Testing

/// Objectif 8 h, réveil 07:00 en semaine et 09:00 le week-end, rappel 30 minutes avant ; midi le vendredi 20 novembre 2026.
struct BedtimeReminderPlannerTests {
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-20T12:00")

    private func plan(goal: Int = 480, weekday: Int? = 420, weekend: Int? = 540, enabled: Bool = true) -> SleepPlan {
        let profile = UserProfile(sleepGoalMinutes: goal, weekdayWakeMinutes: weekday, weekendWakeMinutes: weekend,
                                  bedtimeReminderEnabled: enabled, bedtimeReminderLeadMinutes: 30)
        return SleepPlan(profile: profile, wokeUp: [], calendar: calendar)
    }

    /// `nights` : les minutes endormies par jour de réveil (« 2026-11-20 ») ; `lastNight` : la nuit qui finit le jour de `now`.
    /// `debts` : la dette des 7 nuits par jour de réveil.
    private func reminders(_ plan: SleepPlan? = nil, lastNight: Int? = nil, nights: [String: Int] = [:], debts: [String: Int] = [:],
                           sessions: [String: String] = [:], now: Date? = nil) -> [BedtimeReminder] {
        let now = now ?? self.now
        var nights = nights
        if let lastNight { nights[Self.dayKey(now)] = lastNight }
        return BedtimeReminderPlanner.reminders(plan: plan ?? self.plan(), nightAsleepMinutes: { nights[Self.dayKey($0)] },
                                                sleepDebtMinutes: { debts[Self.dayKey($0)] },
                                                sessionName: { day in sessions[Self.dayKey(day)] }, now: now,
                                                calendar: calendar)
    }

    /// À partir d'une heure, le rappel du soir parle de la dette des 7 nuits plutôt que de la nuit d'hier (#117).
    @Test func aSleepDebtOfAnHourOrMoreIsMentioned() {
        let withSession = reminders(lastNight: 370, debts: ["2026-11-20": 220], sessions: ["2026-11-21": "Push"])
        #expect(withSession.first?.body == "3 h 40 de retard sur 7 jours et séance Push demain : vise tes 8 h.")
        let alone = reminders(lastNight: 370, debts: ["2026-11-20": 220])
        #expect(alone.first?.body == "3 h 40 de retard sur 7 jours : vise tes 8 h cette nuit.")
    }

    @Test func aSmallSleepDebtKeepsTheShortNightText() {
        let planned = reminders(lastNight: 370, debts: ["2026-11-20": 45])
        #expect(planned.first?.body.hasPrefix("Nuit courte hier") == true)
    }

    /// Une dette qui ne vient que de la nuit d'hier (1 h 50 sous l'objectif, 1 h 50 de dette) se dit « nuit courte ».
    @Test func aDebtMadeOfLastNightAloneKeepsTheShortNightText() {
        let planned = reminders(lastNight: 370, debts: ["2026-11-20": 110])
        #expect(planned.first?.body == "Nuit courte hier (6 h 10) : vise tes 8 h cette nuit.")
    }

    /// « 2026-11-23 » pour le jour donné, en heure de Paris.
    private static func dayKey(_ date: Date) -> String {
        let parts = TestClock.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func evening(_ day: String) -> Date { TestClock.date("\(day)T00:00") }

    @Test func sevenEveningsArePlanned() {
        let planned = reminders()
        #expect(BedtimeReminderPlanner.horizonEvenings == 7)
        #expect(planned.map(\.evening) == (20...26).map { evening(String(format: "2026-11-%02d", $0)) })
        #expect(planned.map(\.fireDate) == ["2026-11-21T00:15", "2026-11-22T00:15", "2026-11-22T22:15", "2026-11-23T22:15",
                                            "2026-11-24T22:15", "2026-11-25T22:15", "2026-11-26T22:15"].map { TestClock.date($0) })
    }

    @Test func disabledReminderPlansNothing() {
        #expect(reminders(plan(enabled: false)).isEmpty)
    }

    @Test func noAdvisedBedtimePlansNothing() {
        #expect(reminders(plan(weekday: nil, weekend: nil)).isEmpty)
    }

    @Test func pastReminderIsSkipped() {
        let planned = reminders(now: TestClock.date("2026-11-22T22:30"))
        #expect(planned.first?.evening == evening("2026-11-23"))
        #expect(planned.first?.fireDate == TestClock.date("2026-11-23T22:15"))
        #expect(planned.count == 6)
    }

    @Test func eveningsOutsideTheWindowAreSkippedNotTheOthers() {
        // Réveil du week-end à 12:00 pour 6 h : coucher 05:45, rappel 05:15, hors fenêtre ; la semaine reste à 00:15.
        let planned = reminders(plan(goal: 360, weekday: 420, weekend: 720))
        #expect(planned.count == 5)
        #expect(!planned.map(\.evening).contains(evening("2026-11-20")))
        #expect(!planned.map(\.evening).contains(evening("2026-11-21")))
    }

    @Test func titleGivesTheBedtime() {
        let planned = reminders()
        #expect(planned.first { $0.evening == evening("2026-11-22") }?.title == "Au lit avant 22:45")
        #expect(planned.first { $0.evening == evening("2026-11-20") }?.title == "Au lit avant 00:45")
    }

    @Test func bodyNamesTomorrowsSession() {
        let planned = reminders(sessions: ["2026-11-23": "Jambes"])
        #expect(planned.first { $0.evening == evening("2026-11-22") }?.body
            == "Séance Jambes demain : vise tes 8 h de sommeil.")
    }

    @Test func bodyMentionsAShortNightOnlyTonight() {
        let planned = reminders(lastNight: 370)
        #expect(planned.first?.evening == evening("2026-11-20"))
        #expect(planned.first?.body == "Nuit courte hier (6 h 10) : vise tes 8 h cette nuit.")
        #expect(planned.dropFirst().count == 6)
        #expect(planned.dropFirst().allSatisfy { !$0.body.contains("Nuit courte") })
    }

    @Test func bodyCombinesShortNightAndSession() {
        let planned = reminders(lastNight: 370, sessions: ["2026-11-21": "Jambes"])
        #expect(planned.first?.body == "Nuit courte hier (6 h 10) et séance Jambes demain : vise tes 8 h.")
    }

    @Test func bodyFallsBackToTheWakeTime() {
        let planned = reminders()
        #expect(planned.first { $0.evening == evening("2026-11-22") }?.body
            == "Pour tes 8 h de sommeil avant le réveil de 07:00.")
    }

    @Test func nightJustUnderTheGoalIsNotShort() {
        #expect(reminders(lastNight: 420).allSatisfy { !$0.body.contains("Nuit courte") })
    }

    @Test func eachEveningAppearsOnce() {
        let evenings = reminders().map(\.evening)
        #expect(Set(evenings).count == evenings.count)
        // Le rappel du vendredi sonne le samedi à 00:15 et reste celui du vendredi.
        #expect(reminders().first?.evening == evening("2026-11-20"))
    }

    @Test func rescheduleAfterMidnightKeepsTheEveningStillPending() {
        let planned = reminders(now: TestClock.date("2026-11-21T00:05"))
        #expect(planned.count == 8)
        #expect(planned.first?.evening == evening("2026-11-20"))
        #expect(planned.first?.fireDate == TestClock.date("2026-11-21T00:15"))
        #expect(planned.dropFirst().first?.evening == evening("2026-11-21"))
        #expect(planned.dropFirst().first?.fireDate == TestClock.date("2026-11-22T00:15"))
        #expect(Set(planned.map(\.evening)).count == planned.count)
    }

    @Test func rescheduleAfterTheLateReminderDropsYesterday() {
        let planned = reminders(now: TestClock.date("2026-11-21T00:20"))
        #expect(planned.first?.evening == evening("2026-11-21"))
        #expect(planned.count == 7)
    }

    @Test func shortNightBelongsToTheEveningOfItsWakeDay() {
        let planned = reminders(nights: ["2026-11-20": 370], now: TestClock.date("2026-11-21T00:05"))
        #expect(planned.first { $0.evening == evening("2026-11-20") }?.body
            == "Nuit courte hier (6 h 10) : vise tes 8 h cette nuit.")
        let saturday = planned.first { $0.evening == evening("2026-11-21") }
        #expect(saturday != nil)
        #expect(saturday?.body.contains("Nuit courte") == false)
    }

    @Test func durationsAreWrittenLikeTheApp() {
        #expect(BedtimeReminderText.duration(minutes: 480) == "8 h")
        #expect(BedtimeReminderText.duration(minutes: 370) == "6 h 10")
        #expect(BedtimeReminderText.duration(minutes: 425) == "7 h 05")
        #expect(BedtimeReminderText.duration(minutes: 45) == "45 min")
    }
}
