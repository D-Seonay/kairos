import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

/// Les textes de la section « Sommeil » des réglages.
struct SleepSettingsTextTests {
    @Test func advisedBedtimeNamesBothDays() {
        #expect(ProfileText.advisedBedtime(weekday: 1365, weekend: 45)
            == "Coucher conseillé : 22:45 en semaine, 00:45 le week-end.")
    }

    @Test func advisedBedtimeNamesTheOnlyKnownDay() {
        #expect(ProfileText.advisedBedtime(weekday: 1365, weekend: nil) == "Coucher conseillé : 22:45 en semaine.")
        #expect(ProfileText.advisedBedtime(weekday: nil, weekend: 45) == "Coucher conseillé : 00:45 le week-end.")
    }

    @Test func advisedBedtimeInvitesToChooseAWakeTime() {
        #expect(ProfileText.advisedBedtime(weekday: nil, weekend: nil)
            == "Choisis une heure de réveil pour obtenir un coucher conseillé.")
    }

    @Test func followsNightsShowsTheMeasuredHour() {
        #expect(ProfileText.followsNights(habitual: 420) == "Selon mes nuits (07:00)")
        #expect(ProfileText.followsNights(habitual: nil) == "Selon mes nuits")
    }

    @Test func goalAndLeadAreShortDurations() {
        #expect(ProfileText.sleepGoal(minutes: 480) == "8 h")
        #expect(ProfileText.sleepGoal(minutes: 450) == "7 h 30")
        #expect(ProfileText.bedtimeLead(minutes: 30) == "30 min avant")
    }
}

/// Ce que la section affiche d'un profil venu d'iCloud hors des choix : jamais une sélection sans étiquette.
struct SleepSettingsShownValueTests {
    private func profile(goal: Int? = nil, weekday: Int? = nil, weekend: Int? = nil, lead: Int? = nil) -> UserProfile {
        let created = ProfileTestClock.date(2026, 11, 2, hour: 9)
        var profile = UserProfile(firstName: "Mathéo", onboardingCompletedAt: created, createdAt: created, updatedAt: created)
        profile.sleepGoalMinutes = goal
        profile.weekdayWakeMinutes = weekday
        profile.weekendWakeMinutes = weekend
        profile.bedtimeReminderLeadMinutes = lead
        return profile
    }

    @Test func goalIsClampedThenSnappedToAChoice() {
        #expect(SettingsModel.shownSleepGoal(profile()) == 480)
        #expect(SettingsModel.shownSleepGoal(profile(goal: 457)) == 450)
        #expect(SettingsModel.shownSleepGoal(profile(goal: 458)) == 465)
        #expect(SettingsModel.shownSleepGoal(profile(goal: 1000)) == 600)
        #expect(SettingsModel.shownSleepGoal(profile(goal: 10)) == 360)
        #expect(SettingsService.sleepGoalChoices.contains(SettingsModel.shownSleepGoal(profile(goal: 457))))
    }

    @Test func aWakeOutsideTheRangeIsShownAsFollowingNights() {
        #expect(SettingsModel.chosenWake(profile(weekday: 420), weekend: false) == 420)
        #expect(SettingsModel.chosenWake(profile(weekday: 1000), weekend: false) == nil)
        #expect(SettingsModel.chosenWake(profile(weekend: 200), weekend: true) == nil)
        #expect(SettingsModel.chosenWake(profile(weekday: 420), weekend: true) == nil)
    }

    @Test func leadOutsideTheChoicesIsShownAsTheDefault() {
        #expect(SettingsModel.shownLead(profile()) == 30)
        #expect(SettingsModel.shownLead(profile(lead: 45)) == 45)
        #expect(SettingsModel.shownLead(profile(lead: 20)) == 30)
    }

    @Test func writtenWakeIsRoundedToFiveMinutesInsideTheRange() {
        #expect(SettingsModel.snappedWake(422) == 420)
        #expect(SettingsModel.snappedWake(423) == 425)
        #expect(SettingsModel.snappedWake(100) == 240)
        #expect(SettingsModel.snappedWake(800) == 720)
    }
}
