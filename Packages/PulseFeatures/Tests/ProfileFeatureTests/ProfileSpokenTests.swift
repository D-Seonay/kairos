import Foundation
@testable import ProfileFeature
import PulseDomain
import PulseServices
import Testing

/// Les textes dits de l'onglet Profil : poids, records, badges, Apple Santé, graphique du poids et annonces. Jamais « kg »,
/// « reps », « FC », « tiret », « point médian » ni un mois abrégé.
private enum Spoken {
    static let calendar = ProfileTestClock.calendar
    static let today = ProfileTestClock.now

    static func date(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 12) -> Date {
        ProfileTestClock.date(year, month, day, hour: hour)
    }
}

// MARK: - Poids

struct ProfileWeightSpokenTests {
    @Test func weightsAreSpokenInKilos() {
        #expect(ProfileText.weightSpoken(80) == "80 kilos")
        #expect(ProfileText.weightSpoken(2.5) == "2,5 kilos")
        #expect(ProfileText.weightSpoken(1) == "1 kilo")
        #expect(ProfileText.weightSpoken(.nan) == "indisponible")
    }

    @Test func thirtyDayChangeIsSpokenWithWords() {
        #expect(ProfileText.weightChangeSpoken(-0.8) == "moins 0,8 kilo en 30 jours")
        #expect(ProfileText.weightChangeSpoken(1.3) == "plus 1,3 kilo en 30 jours")
        #expect(ProfileText.weightChangeSpoken(2.4) == "plus 2,4 kilos en 30 jours")
        #expect(ProfileText.weightChangeSpoken(0.04) == "0 kilo en 30 jours")
        #expect(ProfileText.weightChangeSpoken(.infinity) == "indisponible")
    }

    @Test func trendWeightSaysWhenItIsStale() {
        #expect(ProfileText.trendWeightSpoken(78.4, staleSince: nil, calendar: Spoken.calendar, today: Spoken.today) == "78,4 kilos")
        let stale = ProfileText.trendWeightSpoken(78.4, staleSince: Spoken.date(11, 3), calendar: Spoken.calendar,
                                                  today: Spoken.today)
        #expect(stale == "78,4 kilos, dernière mesure le 3 novembre")
    }

    @Test func bodyFatIsSpokenWithItsDate() {
        let reading = BodyFatReading(percent: 17.5, date: Spoken.date(11, 12))
        #expect(ProfileText.bodyFatSpoken(reading, calendar: Spoken.calendar, today: Spoken.today)
            == "17,5 pour cent, le 12 novembre")
    }

    @Test func datesGetTheYearOnlyOutsideThisYear() {
        #expect(ProfileText.spokenDate(Spoken.date(10, 28), calendar: Spoken.calendar, today: Spoken.today) == "28 octobre")
        #expect(ProfileText.spokenDate(Spoken.date(10, 28, year: 2025), calendar: Spoken.calendar, today: Spoken.today)
            == "28 octobre 2025")
    }

    @Test func weightCardIsOneSentence() {
        let old = Spoken.date(10, 25)
        let recent = Spoken.date(11, 18, hour: 7)
        let measurements = [
            BodyMeasurement(date: old, weightKg: 79.2, source: .manual, createdAt: old, updatedAt: old),
            BodyMeasurement(date: recent, weightKg: 78.4, bodyFatPercent: 17.5, source: .appleHealth, createdAt: recent,
                            updatedAt: recent)
        ]
        let trend = WeightTrend.make(measurements: measurements, now: Spoken.today, calendar: Spoken.calendar)
        let text = ProfileText.weightCardSpoken(trend: trend, calendar: Spoken.calendar, today: Spoken.today)
        #expect(text.hasPrefix("Poids et corps, "))
        #expect(text.contains("tendance sur 7 jours"))
        #expect(text.contains("masse grasse 17,5 pour cent, le 18 novembre"))
        for banned in ["kg", "·", "nov.", "−"] { #expect(!text.contains(banned), "« \(banned) » dans \(text)") }
    }

    @Test func weightCardWithoutWeighInGivesTheReason() {
        #expect(ProfileText.weightCardSpoken(trend: nil, calendar: Spoken.calendar, today: Spoken.today)
            == "Poids et corps, pas encore de pesée, ajoute une pesée ou autorise le poids dans Apple Santé")
    }

    @Test func measurementRowsAreSpokenValueFirst() {
        let date = Spoken.date(10, 28, hour: 7)
        let both = BodyMeasurement(date: date, weightKg: 78.4, bodyFatPercent: 17.5, source: .manual, createdAt: date, updatedAt: date)
        let fat = BodyMeasurement(date: date, bodyFatPercent: 18, source: .appleHealth, createdAt: date, updatedAt: date)
        #expect(ProfileText.measurementSpoken(both, calendar: Spoken.calendar, today: Spoken.today)
            == "78,4 kilos, 17,5 pour cent de masse grasse, le 28 octobre, saisie manuelle")
        #expect(ProfileText.measurementSpoken(fat, calendar: Spoken.calendar, today: Spoken.today)
            == "18 pour cent de masse grasse, le 28 octobre, Apple Santé")
    }
}

// MARK: - Graphique du poids

struct WeightChartSpokenTests {
    private func day(_ month: Int, _ dayOfMonth: Int, _ kilos: Double) -> WeightDay {
        WeightDay(date: Spoken.date(month, dayOfMonth, hour: 0), weightKg: kilos, source: .manual)
    }

    @Test func summaryGivesPeriodTrendRangeAndCount() {
        let weighed = [day(8, 25, 80.3), day(10, 1, 79), day(11, 20, 77.6)]
        let text = ProfileText.weightChartSummary(weighed: weighed, current: 78.4, calendar: Spoken.calendar, today: Spoken.today)
        #expect(text == "Poids sur 90 jours, du 25 août au 20 novembre : tendance 78,4 kilos, de 77,6 à 80,3 kilos, 3 pesées.")
    }

    @Test func summaryWithoutTrendOrWithASingleWeighIn() {
        let two = [day(11, 1, 79), day(11, 20, 78)]
        #expect(ProfileText.weightChartSummary(weighed: two, current: nil, calendar: Spoken.calendar, today: Spoken.today)
            == "Poids sur 90 jours, du 1 novembre au 20 novembre : de 78 à 79 kilos, 2 pesées.")
        let flat = [day(11, 1, 78), day(11, 20, 78)]
        #expect(ProfileText.weightChartSummary(weighed: flat, current: nil, calendar: Spoken.calendar, today: Spoken.today)
            == "Poids sur 90 jours, du 1 novembre au 20 novembre : à 78 kilos, 2 pesées.")
        let one = [day(11, 20, 78.2)]
        #expect(ProfileText.weightChartSummary(weighed: one, current: 78.2, calendar: Spoken.calendar, today: Spoken.today)
            == "Poids sur 90 jours, le 20 novembre : tendance 78,2 kilos, 1 pesée.")
    }

    @Test func pointsAreSpokenWithDateAndKilos() {
        let spoken = ProfileText.weightPointSpoken(day(11, 12, 78.4), calendar: Spoken.calendar, today: Spoken.today)
        #expect(spoken.label == "12 novembre" && spoken.value == "78,4 kilos")
    }
}

// MARK: - Records et badges

struct ProfileRecordSpokenTests {
    private func lift(kind: RecordKind = .estimatedOneRepMax, value: Double = 120, date: Date = Spoken.date(10, 28)) -> StrengthRecordLine {
        StrengthRecordLine(exercise: .content(id: "back-squat-barbell"), name: "Squat", kind: kind, value: value, weightKg: nil,
                           reps: nil, date: date, gain: nil, isNew: false)
    }

    @Test func raceTimesAreSpokenAsDurations() {
        #expect(ProfileText.raceTimeSpoken(seconds: 1_471) == "24 minutes 31")
        #expect(ProfileText.raceTimeSpoken(seconds: 6_307) == "1 heure 45 minutes 7")
        #expect(ProfileText.raceTimeSpoken(seconds: .infinity) == "indisponible")
    }

    @Test func recordValuesSpellOutKilosAndRepetitions() {
        #expect(ProfileText.recordValueSpoken(lift()) == "120 kilos")
        #expect(ProfileText.recordValueSpoken(lift(kind: .repsAtWeight, value: 14)) == "14 répétitions")
        #expect(ProfileText.recordValueSpoken(lift(kind: .repsAtWeight, value: 1)) == "1 répétition")
    }

    @Test func liftRowGivesTheValueFirst() {
        #expect(ProfileText.liftRecordSpoken(title: "Squat", line: lift(), calendar: Spoken.calendar, today: Spoken.today)
            == "Squat : 120 kilos, le 28 octobre")
        #expect(ProfileText.liftRecordSpoken(title: "Soulevé de terre", line: nil, calendar: Spoken.calendar, today: Spoken.today)
            == "Soulevé de terre : pas encore de record")
    }

    @Test func runRowsSpellOutTheDistance() {
        let best = RunBest(distance: .fiveK, seconds: 1_471, date: Spoken.date(9, 14), isNew: false)
        #expect(ProfileText.runRecordSpoken(best, calendar: Spoken.calendar, today: Spoken.today)
            == "5 kilomètres : 24 minutes 31, le 14 septembre")
        let none = RunBest(distance: .tenK, seconds: nil, date: nil, isNew: false)
        #expect(ProfileText.runRecordSpoken(none, calendar: Spoken.calendar, today: Spoken.today)
            == "10 kilomètres : pas encore couru")
        let half = RunBest(distance: .half, seconds: 6_307, date: nil, isNew: false)
        #expect(ProfileText.runRecordSpoken(half, calendar: Spoken.calendar, today: Spoken.today)
            == "Semi-marathon : 1 heure 45 minutes 7")
    }

    @Test func badgesSayWhetherTheyAreEarned() {
        let earned = Badge(kind: .streak(weeks: 4), earnedAt: Spoken.date(10, 28), current: 4, goal: 4)
        #expect(ProfileText.badgeAccessibility(earned, calendar: Spoken.calendar, today: Spoken.today)
            == "4 semaines d'affilée, obtenu le 28 octobre")
        let streak = Badge(kind: .streak(weeks: 10), earnedAt: nil, current: 9, goal: 12)
        #expect(ProfileText.badgeAccessibility(streak, calendar: Spoken.calendar, today: Spoken.today)
            == "10 semaines d'affilée, pas encore obtenu, 9 sur 12 semaines")
        let sessions = Badge(kind: .sessions(count: 50), earnedAt: nil, current: 37, goal: 50)
        #expect(ProfileText.badgeAccessibility(sessions, calendar: Spoken.calendar, today: Spoken.today)
            == "50 séances, pas encore obtenu, 37 sur 50 séances")
        let month = Badge(kind: .firstFullMonth, earnedAt: nil, current: 2, goal: 4)
        #expect(ProfileText.badgeAccessibility(month, calendar: Spoken.calendar, today: Spoken.today)
            == "Premier mois complet, pas encore obtenu, 2 sur 4 semaines")
    }
}

// MARK: - Tuiles et en-tête

struct ProfileHeaderSpokenTests {
    @Test func morningScoreIsSpokenOutOfOneHundred() {
        #expect(ProfileText.morningScoreSpoken(58, isEstimated: true) == "58 sur 100, estimé")
        #expect(ProfileText.morningScoreSpoken(58.4, isEstimated: false) == "58 sur 100")
    }

    @Test func tilesAreOneSentence() {
        #expect(ProfileText.tileSpoken(title: "Score du matin", value: "58", unit: "sur 100 · Estimé", spoken: "58 sur 100, estimé",
                                       emptyText: "Pas encore de score aujourd'hui") == "Score du matin, 58 sur 100, estimé")
        #expect(ProfileText.tileSpoken(title: "Poids", value: "78,4", unit: "kg", spoken: nil, emptyText: "Pas encore de pesée")
            == "Poids, 78,4 kg")
        #expect(ProfileText.tileSpoken(title: "Poids", value: nil, unit: nil, spoken: nil, emptyText: "Pas encore de pesée")
            == "Poids, Pas encore de pesée")
    }

    @Test func headerNamesTheScreenFirst() {
        #expect(ProfileText.headerSpoken(name: "Mathéo", sessions: "12 séances, depuis mars 2026")
            == "Profil, Mathéo, 12 séances, depuis mars 2026")
        #expect(ProfileText.headerSpoken(name: "Ton profil", sessions: nil) == "Profil, Ton profil")
    }

    @Test func sessionsSinceHasNoMiddleDot() {
        #expect(ProfileText.sessionsSinceSpoken(12, firstSession: Spoken.date(3, 4), calendar: Spoken.calendar)
            == "12 séances, depuis mars 2026")
        #expect(ProfileText.sessionsSinceSpoken(1, firstSession: Spoken.date(3, 4), calendar: Spoken.calendar)
            == "1 séance, depuis mars 2026")
        #expect(ProfileText.sessionsSinceSpoken(0, firstSession: nil, calendar: Spoken.calendar) == "Aucune séance pour l'instant")
    }
}

// MARK: - Paramètres

@MainActor
struct SettingsSpokenTests {
    @Test func healthKindsAreNotAbbreviated() {
        #expect(ProfileText.healthKindSpoken(.sdnn) == "Variabilité de la fréquence cardiaque")
        #expect(ProfileText.healthKindSpoken(.restingHeartRate) == "Fréquence cardiaque au repos")
        #expect(ProfileText.healthKindSpoken(.sleep) == "Sommeil")
    }

    @Test func healthRowsAreOneSentence() {
        #expect(ProfileText.healthRowSpoken(.sleep, latest: Spoken.date(11, 12), calendar: Spoken.calendar, today: Spoken.today)
            == "Sommeil, dernière donnée le 12 novembre")
        #expect(ProfileText.healthRowSpoken(.run, latest: nil, calendar: Spoken.calendar, today: Spoken.today)
            == "Courses, aucune donnée lue")
    }

    @Test func lastReadIsSpokenWithClockTime() {
        let date = Spoken.date(11, 12, hour: 7)
        #expect(ProfileText.lastReadSpoken(date, calendar: Spoken.calendar, today: Spoken.today)
            == "Dernière donnée reçue : 12 novembre à 7 heures")
        #expect(ProfileText.lastReadSpoken(nil, calendar: Spoken.calendar, today: Spoken.today) == "Dernière donnée reçue : jamais")
    }

    @Test func choicesAreSpokenWithTheirUnit() {
        #expect(ProfileText.restSpoken(90) == "90 secondes")
        #expect(ProfileText.restSpoken(60) == "60 secondes")
        #expect(ProfileText.plateSpoken(20) == "20 kilos")
        #expect(ProfileText.plateSpoken(2.5) == "2,5 kilos")
        #expect(ProfileText.plateSpoken(1.25) == "1,25 kilo")
        #expect(ProfileText.plateSpoken(0.5) == "0,5 kilo")
    }

    @Test func deadlinesAreSpokenAsClockTimes() {
        #expect(ProfileText.clockSpoken(minutes: 6 * 60) == "6 heures")
        #expect(ProfileText.clockSpoken(minutes: 10 * 60 + 30) == "10 heures 30")
    }

    @Test func fieldLabelsCarryTheUnit() {
        #expect(ProfileText.heightFieldLabel == "Taille, en centimètres")
        #expect(ProfileText.weightFieldLabel == "Poids, en kilos")
    }

    @Test func settingsErrorsHaveNoAbbreviations() {
        for error in [SettingsError.invalidHeight, .invalidIncrement, .invalidRest, .invalidDeadline, .invalidPlates, .noProfile] {
            let message = SettingsModel.message(for: error)
            for banned in [" cm", " kg", " s.", " h "] { #expect(!message.contains(banned), "« \(banned) » dans \(message)") }
        }
        #expect(WeightModel.invalidWeightMessage == "Entre un poids entre 20 et 400 kilos.")
    }
}

// MARK: - Annonces

@MainActor
struct ProfileAnnouncementTests {
    @Test func operationsHaveFixedSentences() {
        #expect(ProfileText.exportStarted == "Export en cours")
        #expect(ProfileText.exportReady == "Export prêt. Touche Partager l'export.")
        #expect(ProfileText.healthReadStarted == "Lecture d'Apple Santé en cours")
        #expect(ProfileText.healthReadFinished == "Lecture d'Apple Santé terminée")
    }

    @Test func unreadableCountsAreSpokenAsUnavailable() {
        #expect(MyDataModel.countSpoken(nil, hasRefreshed: true) == "indisponible")
        #expect(MyDataModel.countSpoken(nil, hasRefreshed: false) == "Pas encore lu")
        #expect(MyDataModel.countSpoken(12, hasRefreshed: true) == "12")
        #expect(MyDataModel.countText(nil, hasRefreshed: true) == "—")
    }
}
