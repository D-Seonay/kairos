import Foundation
import PulseDomain
import PulseRecoveryEngine
import Testing

struct LoadDropRuleTests {
    private let bar = WeightRounding.plates(barKg: 20, smallestPlateKg: 1.25)

    private func routine(sets: Int = 3, range: ClosedRange<Int> = 8...12) -> RoutineExercise {
        RoutineExercise(order: 0, exercise: .content(id: "exercise"), sets: sets, repsMin: range.lowerBound,
                        repsMax: range.upperBound, targetRPE: 8, restSeconds: 90)
    }

    /// Une série faite ; `planned` : les répétitions proposées ce jour-là, le bas de la fourchette 8–12 par défaut.
    private func done(_ weight: Double?, _ reps: Int?, type: SetType = .working, seconds: Int? = nil,
                      planned: Int? = 8) -> WorkoutSet {
        WorkoutSet(order: 0, exercise: .content(id: "exercise"), exerciseName: "Exercice", setType: type, plannedReps: planned,
                   actualWeightKg: weight, actualReps: reps, durationSeconds: seconds)
    }

    private func drop(days: Int?, recent: [[WorkoutSet]] = [], range: ClosedRange<Int> = 8...12) -> LoadDrop? {
        LoadDropRule.drop(daysSinceLast: days, recentSets: recent, exercise: routine(range: range), tracksDuration: false)
    }

    // MARK: - Reprise

    @Test func theLayoffCurveStepsUpWithTheWeeksOff() {
        let days = [0, 13, 14, 20, 21, 34, 35, 41, 42, 120]
        #expect(days.map(LoadDropRule.layoffPercent(daysSinceLast:)) == [nil, nil, 5, 5, 10, 10, 15, 15, 20, 20])
    }

    @Test func thePauseIsCountedInCalendarDays() throws {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        // Lundi 19 h, puis deux lundis plus tard à 18 h 30 : 14 jours de calendrier, même s'il manque une demi-heure.
        let monday = try #require(paris.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 19)))
        let twoMondaysLater = try #require(paris.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 18, minute: 30)))
        #expect(LoadDropRule.calendarDays(from: monday, to: twoMondaysLater, calendar: paris) == 14)
        // Dimanche 23 h puis lundi 1 h : un jour.
        let sunday = try #require(paris.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23)))
        let mondayNight = try #require(paris.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 1)))
        #expect(LoadDropRule.calendarDays(from: sunday, to: mondayNight, calendar: paris) == 1)
    }

    @Test func aLayoffNamesTheWeeksAndThePercent() throws {
        let layoff = try #require(drop(days: 37))
        #expect(layoff.reason == .layoff(weeks: 5) && layoff.percent == 15)
        #expect(abs(layoff.factor - 0.85) < 1e-9)
        #expect(layoff.text == "Reprise après 5 semaines : −15 %")
        #expect(drop(days: 10) == nil && drop(days: nil) == nil)
    }

    @Test func aLayoffWinsOverOldMisses() {
        let missed = [[done(60, 6)], [done(60, 6)]]
        #expect(drop(days: 50, recent: missed)?.reason == .layoff(weeks: 7))
    }

    // MARK: - Échecs répétés

    @Test func twoSessionsInARowUnderTheRangeDropFivePercent() throws {
        let recent = [[done(60, 7), done(60, 8), done(60, 8)], [done(60, 6), done(60, 8), done(60, 9)]]
        let misses = try #require(drop(days: 3, recent: recent))
        #expect(misses.reason == .misses && misses.percent == 5)
        #expect(misses.text == "Deux séances sous la fourchette : −5 %")
    }

    @Test func missingMostSetsTwiceDropsTenPercent() {
        let recent = [[done(60, 7), done(60, 6), done(60, 8)], [done(60, 6), done(60, 7), done(60, 9)]]
        #expect(drop(days: 3, recent: recent)?.percent == 10)
    }

    @Test func oneMissedSessionOrMissesThatAreNotInARowDropNothing() {
        #expect(drop(days: 3, recent: [[done(60, 7)], [done(60, 9)]]) == nil)
        #expect(drop(days: 3, recent: [[done(60, 9)], [done(60, 7)]]) == nil)
        #expect(drop(days: 3, recent: [[done(60, 7)]]) == nil)
    }

    @Test func dropSetsAndUnloggedSetsAreNotMisses() {
        let recent = [[done(60, 8), done(40, 5, type: .drop), done(60, nil)], [done(60, 9), done(40, 4, type: .drop)]]
        #expect(drop(days: 3, recent: recent) == nil)
    }

    @Test func aPerSetRangeIsReadSetBySet() {
        var ramping = routine(range: 4...12)
        ramping.setTargets = [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6)]
        let recent = [[done(60, 10, planned: 10), done(70, 4, planned: 4)], [done(60, 11, planned: 10), done(70, 5, planned: 4)]]
        #expect(LoadDropRule.drop(daysSinceLast: 3, recentSets: recent, exercise: ramping, tracksDuration: false) == nil)
        let missed = [[done(60, 9, planned: 10), done(70, 4, planned: 4)], [done(60, 9, planned: 10), done(70, 5, planned: 4)]]
        #expect(LoadDropRule.drop(daysSinceLast: 3, recentSets: missed, exercise: ramping, tracksDuration: false)?.percent == 5)
    }

    @Test func pastSetsAreJudgedAgainstTheirOwnTarget() {
        // Un squat fait en 5 × 5, ajouté en séance avec la fourchette par défaut (8–12) ou passé à un programme en 8–12 :
        // 5 répétitions sur 5 prévues ne sont pas des échecs.
        let fiveByFive = [[done(100, 5, planned: 5), done(100, 5, planned: 5)], [done(100, 5, planned: 5), done(100, 5, planned: 5)]]
        #expect(drop(days: 3, recent: fiveByFive) == nil)
        // Sous les 5 prévues, deux fois : un échec, même lu avec la fourchette 8–12.
        let missedFives = [[done(100, 4, planned: 5), done(100, 5, planned: 5)], [done(100, 4, planned: 5), done(100, 5, planned: 5)]]
        #expect(drop(days: 3, recent: missedFives)?.percent == 5)
        // Une proposition au-dessus du bas de la fourchette (9 prévues, 8 faites) reste dans la fourchette.
        #expect(drop(days: 3, recent: [[done(60, 8, planned: 9)], [done(60, 8, planned: 9)]]) == nil)
    }

    @Test func withoutAPastTargetTheMissRuleStaysQuiet() {
        // Une série sans proposition enregistrée (importée, saisie sans proposition) ne dit pas quelle était la cible.
        #expect(drop(days: 3, recent: [[done(60, 5, planned: nil)], [done(60, 5, planned: nil)]]) == nil)
        // Un exercice tenu n'enregistre pas sa durée prévue.
        let held = [[done(10, nil, seconds: 25, planned: nil)], [done(10, nil, seconds: 20, planned: nil)]]
        #expect(LoadDropRule.drop(daysSinceLast: 3, recentSets: held, exercise: routine(range: 30...60), tracksDuration: true) == nil)
    }

    // MARK: - Charges baissées

    @Test func aLoweredLoadIsRoundedAndAlwaysAtLeastOneStepDown() {
        #expect(LoadDropRule.lower(100, factor: 0.85, incrementKg: 2.5, rounding: bar) == 85)
        #expect(LoadDropRule.lower(60, factor: 0.95, incrementKg: 2.5, rounding: bar) == 57.5)
        // 19 kg n'existe pas : l'haltère descend d'un cran.
        #expect(LoadDropRule.lower(20, factor: 0.95, incrementKg: 2, rounding: .increment) == 18)
        // La barre seule ne descend pas.
        #expect(LoadDropRule.lower(20, factor: 0.8, incrementKg: 2.5, rounding: bar) == 20)
    }

    @Test func aSmallLoadNeverDropsToZeroNorByFarMoreThanTheRule() {
        // Un haltère de 2 kg au pas de 2 kg, une machine à 5 kg au pas de 5 kg : jamais 0 kg.
        #expect(LoadDropRule.lower(2, factor: 0.8, incrementKg: 2, rounding: .increment) == 2)
        #expect(LoadDropRule.lower(5, factor: 0.85, incrementKg: 5, rounding: .increment) == 5)
        // 4 kg → 2 kg, ce serait −50 % pour une règle à −5 % : la charge reste.
        #expect(LoadDropRule.lower(4, factor: 0.95, incrementKg: 2, rounding: .increment) == 4)
        // Un cran d'au plus deux fois la baisse voulue passe : 10 kg −20 % au pas de 2,5 → 7,5 kg.
        #expect(LoadDropRule.lower(10, factor: 0.8, incrementKg: 2.5, rounding: .increment) == 7.5)
        // 2,5 kg sous le pas de 2,5 kg après une pause de six semaines : jamais sous la plus petite charge.
        #expect(LoadDropRule.lower(2.5, factor: 0.8, incrementKg: 2.5, rounding: .increment) == 2.5)
    }

    @Test func aSmallLoadThatCannotDropGivesNoLoweredSets() throws {
        let layoff = try #require(drop(days: 20))
        #expect(LoadDropRule.lowered([ProposedSet(weightKg: 4, reps: 10)], lastSets: [done(4, 10)], exercise: routine(sets: 1),
                                     tracksDuration: false, drop: layoff, incrementKg: 2, rounding: .increment) == nil)
    }

    @Test func theLoweredSetsStartFromLastTimeAtTheBottomOfTheRange() throws {
        let layoff = try #require(drop(days: 45))
        let last = [done(100, 12), done(100, 10)]
        let proposed = [ProposedSet(weightKg: 102.5, reps: 8, isIncrease: true), ProposedSet(weightKg: 100, reps: 11)]
        let lowered = try #require(LoadDropRule.lowered(proposed, lastSets: last, exercise: routine(sets: 2), tracksDuration: false,
                                                        drop: layoff, incrementKg: 2.5, rounding: bar))
        #expect(lowered == [ProposedSet(weightKg: 80, reps: 8), ProposedSet(weightKg: 80, reps: 8)])
    }

    @Test func nothingToLowerGivesNoLoweredSets() throws {
        let layoff = try #require(drop(days: 45))
        let unloaded = [ProposedSet(weightKg: nil, reps: 9)]
        #expect(LoadDropRule.lowered(unloaded, lastSets: [done(nil, 8)], exercise: routine(sets: 1), tracksDuration: false,
                                     drop: layoff, incrementKg: 2.5, rounding: bar) == nil)
        let atTheBar = [ProposedSet(weightKg: 20, reps: 9)]
        #expect(LoadDropRule.lowered(atTheBar, lastSets: [done(20, 8)], exercise: routine(sets: 1), tracksDuration: false,
                                     drop: layoff, incrementKg: 2.5, rounding: bar) == nil)
    }
}
