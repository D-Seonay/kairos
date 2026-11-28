import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

/// Mercredi 18 novembre 2026, 6 h : l'onboarding est fini depuis le 1er novembre.
struct CheckInReminderRuleTests {
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-18T06:00")
    private let onboarded = TestClock.date("2026-11-01T09:00")

    private func context(watch: String? = nil, onboarded: Date? = TestClock.date("2026-11-01T09:00"), doneToday: Bool = false,
                         weekdayWake: Int? = 7 * 60, weekendWake: Int? = 9 * 60) -> CheckInReminderContext {
        CheckInReminderContext(lastWatchSample: watch.map(TestClock.date), onboardingCompletedAt: onboarded, doneToday: doneToday,
                               weekdayWake: weekdayWake, weekendWake: weekendWake)
    }

    private func reminders(_ context: CheckInReminderContext,
                           settings: CheckInReminderSettings = CheckInReminderSettings()) -> [CheckInReminder] {
        CheckInReminderRule.reminders(settings: settings, context: context, now: now, calendar: calendar)
    }

    @Test func offeredAfterThreeDaysWithoutWatchData() {
        func offered(_ watch: String?, onboarded: Date? = onboarded) -> Bool {
            CheckInReminderRule.isOffered(lastWatchSample: watch.map(TestClock.date), onboardingCompletedAt: onboarded, now: now,
                                          calendar: calendar)
        }
        #expect(!offered("2026-11-17T06:30"), "Une mesure hier : la montre est là")
        #expect(!offered("2026-11-16T06:30"))
        #expect(offered("2026-11-15T06:30"), "Trois jours sans mesure")
        #expect(offered(nil), "Jamais de mesure")
        #expect(!offered(nil, onboarded: TestClock.date("2026-11-16T20:00")), "Un nouveau profil attend ses premières mesures")
        #expect(offered(nil, onboarded: TestClock.date("2026-11-15T20:00")))
        #expect(!offered(nil, onboarded: nil), "Pas avant la fin de l'onboarding")
    }

    @Test func oneReminderEachMorningAtTheUsualWakeTime() {
        let result = reminders(context())
        #expect(result.map(\.fireDate) == [TestClock.date("2026-11-18T07:00"), TestClock.date("2026-11-19T07:00")])
        #expect(result.first?.day == TestClock.date("2026-11-18T00:00"))
        #expect(result.allSatisfy { $0.title == "Comment tu te sens ?" })
        let friday = CheckInReminderRule.reminders(settings: CheckInReminderSettings(), context: context(),
                                                   now: TestClock.date("2026-11-20T06:00"), calendar: calendar)
        #expect(friday.last?.fireDate == TestClock.date("2026-11-21T09:00"), "Le week-end, au réveil du week-end")
    }

    @Test func onlyTodayAndTomorrowAreBookedAhead() {
        // Une montre remise une nuit iPhone verrouillé ne peut rien annuler : au plus deux rappels partent pour rien. Une réponse
        // rapide ou un passage d'arrière-plan replanifie et prolonge la suite.
        #expect(CheckInReminderRule.horizonDays == 2)
        let late = CheckInReminderRule.reminders(settings: CheckInReminderSettings(), context: context(),
                                                 now: TestClock.date("2026-11-18T07:30"), calendar: calendar)
        #expect(late.map(\.day) == [TestClock.date("2026-11-19T00:00")])
    }

    @Test func aChosenTimeWinsAndEightIsTheFallback() {
        let chosen = reminders(context(), settings: CheckInReminderSettings(chosenMinutes: 6 * 60 + 30))
        #expect(chosen.allSatisfy { calendar.dateComponents([.hour, .minute], from: $0.fireDate) == DateComponents(hour: 6, minute: 30) })
        let fallback = reminders(context(weekdayWake: nil, weekendWake: nil))
        #expect(fallback.allSatisfy { calendar.component(.hour, from: $0.fireDate) == 8 })
    }

    @Test func nothingTodayOnceTheCheckInOrAMeasuredScoreExists() {
        let result = reminders(context(doneToday: true))
        #expect(result.count == CheckInReminderRule.horizonDays - 1)
        #expect(result.first?.day == TestClock.date("2026-11-19T00:00"))
    }

    @Test func nothingTodayOnceTheTimeHasPassed() {
        let late = CheckInReminderRule.reminders(settings: CheckInReminderSettings(), context: context(),
                                                 now: TestClock.date("2026-11-18T07:00"), calendar: calendar)
        #expect(late.first?.day == TestClock.date("2026-11-19T00:00"))
    }

    @Test func nothingWhenTurnedOffOrWhenTheWatchSendsData() {
        #expect(reminders(context(), settings: CheckInReminderSettings(enabled: false)).isEmpty)
        #expect(reminders(context(watch: "2026-11-18T05:30")).isEmpty)
    }

    @Test func todayStillNeedsTheCheckInAfterTheReminderTime() {
        func needed(_ context: CheckInReminderContext, settings: CheckInReminderSettings = CheckInReminderSettings(),
                    at text: String = "2026-11-18T08:20") -> Bool {
            CheckInReminderRule.isNeededToday(settings: settings, context: context, now: TestClock.date(text), calendar: calendar)
        }
        #expect(needed(context()), "Le rappel de 7 h est passé, le check-in reste à faire")
        #expect(needed(context(), at: "2026-11-18T06:00"))
        #expect(!needed(context(doneToday: true)), "Check-in ou score mesuré du jour")
        #expect(!needed(context(), settings: CheckInReminderSettings(enabled: false)), "Réglage coupé")
        #expect(!needed(context(watch: "2026-11-18T05:30")), "La montre est revenue")
        #expect(!needed(context(onboarded: nil)))
    }

    @Test func quickAnswersAreFullCheckIns() {
        #expect(CheckInQuickAnswer.allCases.map(\.title) == ["En forme", "Moyen", "Fatigué"])
        #expect(CheckInQuickAnswer.allCases.map { CheckInScorer.score($0.answers) } == [75, 50, 33.75])
    }
}
