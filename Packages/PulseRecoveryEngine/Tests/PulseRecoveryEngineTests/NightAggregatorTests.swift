import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

@Suite struct NightAggregatorTests {
    let aggregator = NightAggregator(calendar: TestCalendar.paris)
    let day = TestCalendar.day(2026, 11, 20)
    let d = TestCalendar.date

    /// Nuit du 19 au 20 novembre : 450 min endormi dont 90 profond, une pause éveillée de 10 min.
    var typicalSleep: [SleepInterval] {
        [SleepInterval(start: d(2026, 11, 19, 23, 10), end: d(2026, 11, 20, 1, 0), stage: .core),
         .init(start: d(2026, 11, 20, 1, 0), end: d(2026, 11, 20, 2, 30), stage: .deep),
         .init(start: d(2026, 11, 20, 2, 30), end: d(2026, 11, 20, 3, 30), stage: .rem),
         .init(start: d(2026, 11, 20, 3, 30), end: d(2026, 11, 20, 3, 40), stage: .awake),
         .init(start: d(2026, 11, 20, 3, 40), end: d(2026, 11, 20, 6, 50), stage: .core)]
    }

    var typicalSDNN: [TimedSample] {
        [TimedSample(date: d(2026, 11, 19, 22, 0), value: 40), .init(date: d(2026, 11, 20, 0, 30), value: 48),
         .init(date: d(2026, 11, 20, 2, 0), value: 52), .init(date: d(2026, 11, 20, 5, 0), value: 50),
         .init(date: d(2026, 11, 20, 9, 0), value: 70)]
    }

    @Test func typicalNight() {
        let rhr = [TimedSample(date: d(2026, 11, 20, 10, 0), value: 49)]
        let n = aggregator.night(for: day, sdnn: typicalSDNN, restingHeartRate: rhr, sleep: typicalSleep)
        #expect(n == NightSample(day: day, sdnnMs: 50, sdnnSampleCount: 3, restingHeartRate: 49,
                                 restingHeartRateSource: .appleNearWake, sleep: typicalSummary))
    }

    @Test func noSleepFallsBackToMidnightToEight() {
        let sdnn = [TimedSample(date: d(2026, 11, 20, 0, 30), value: 48), .init(date: d(2026, 11, 20, 5, 0), value: 50),
                    .init(date: d(2026, 11, 20, 9, 0), value: 70)]
        let n = aggregator.night(for: day, sdnn: sdnn, restingHeartRate: [], sleep: [])
        #expect(n.sdnnMs == 49)
        #expect(n.sleep == nil)
        #expect(n.restingHeartRate == nil)
    }

    /// Un assoupissement devant la télé à 19 h, la nuit à 23 h 10 : ni la mesure prise pendant l'assoupissement, ni celle de
    /// la soirée éveillée n'entrent dans la moyenne de la nuit.
    @Test func eveningDozeAndWakingEveningStayOutOfTheMean() {
        let doze = SleepInterval(start: d(2026, 11, 19, 19, 0), end: d(2026, 11, 19, 19, 30), stage: .core)
        let sdnn = typicalSDNN + [TimedSample(date: d(2026, 11, 19, 19, 15), value: 80), .init(date: d(2026, 11, 19, 21, 0), value: 90)]
        let n = aggregator.night(for: day, sdnn: sdnn, restingHeartRate: [], sleep: typicalSleep + [doze])
        #expect(n.sdnnMs == 50)
        #expect(n.sleep?.asleepMinutes == 480, "L'assoupissement reste compté dans le sommeil")
    }

    /// Une sieste à 10 h : la mesure de la matinée éveillée et celle de la sieste restent hors de la moyenne.
    @Test func morningNapAndWakingMorningStayOutOfTheMean() {
        let nap = SleepInterval(start: d(2026, 11, 20, 10, 0), end: d(2026, 11, 20, 10, 40), stage: .core)
        let sdnn = typicalSDNN + [TimedSample(date: d(2026, 11, 20, 10, 20), value: 95)]
        let n = aggregator.night(for: day, sdnn: sdnn, restingHeartRate: [], sleep: typicalSleep + [nap])
        #expect(n.sdnnMs == 50)
    }

    /// Une mesure prise pendant l'éveil de 3 h 30, ou dans un trou sans donnée du bloc principal, n'est pas une mesure endormie.
    @Test func samplesWhileAwakeInsideTheMainBlockAreIgnored() {
        let awake = TimedSample(date: d(2026, 11, 20, 3, 35), value: 100)
        let n = aggregator.night(for: day, sdnn: typicalSDNN + [awake], restingHeartRate: [], sleep: typicalSleep)
        #expect(n.sdnnMs == 50)

        let withGap = [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 2, 0), stage: .asleepUnspecified),
                       .init(start: d(2026, 11, 20, 2, 30), end: d(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]
        let sdnn = [TimedSample(date: d(2026, 11, 20, 1, 0), value: 44), .init(date: d(2026, 11, 20, 2, 15), value: 100),
                    .init(date: d(2026, 11, 20, 4, 0), value: 56)]
        #expect(aggregator.night(for: day, sdnn: sdnn, restingHeartRate: [], sleep: withGap).sdnnMs == 50)
    }

    /// Aucune mesure pendant le sommeil du bloc principal : la nuit n'a pas de SDNN, même avec des mesures autour.
    @Test func noSampleWhileAsleepInTheMainBlockGivesNoSDNN() {
        let doze = SleepInterval(start: d(2026, 11, 19, 19, 0), end: d(2026, 11, 19, 19, 30), stage: .core)
        let sdnn = [TimedSample(date: d(2026, 11, 19, 19, 15), value: 80), .init(date: d(2026, 11, 19, 21, 0), value: 90),
                    .init(date: d(2026, 11, 20, 3, 35), value: 100), .init(date: d(2026, 11, 20, 7, 30), value: 70)]
        let n = aggregator.night(for: day, sdnn: sdnn, restingHeartRate: [], sleep: typicalSleep + [doze])
        #expect(n.sdnnMs == nil)
        #expect(n.sleep != nil)
    }

    @Test func unspecifiedSleepHasNoDeepMinutes() {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: [], sleep: sleep)
        #expect(n.sleep == SleepSummary(asleepMinutes: 480, deepMinutes: nil))
    }

    @Test func overlappingSourcesAreMergedNotSummed() {
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: [], sleep: typicalSleep + typicalSleep)
        #expect(n.sleep == typicalSummary)
    }

    /// Le résumé de `typicalSleep` : 300 min de léger, 90 de profond, 60 de paradoxal, 10 d'éveil.
    var typicalSummary: SleepSummary {
        SleepSummary(asleepMinutes: 450, deepMinutes: 90, coreMinutes: 300, remMinutes: 60, unspecifiedMinutes: 0, awakeMinutes: 10)
    }

    /// Le moteur de l'écran Nuit et celui du score comptent les mêmes minutes endormies et profondes pour la même nuit.
    @Test func builderAgreesWithAggregatorOnTotals() {
        let builder = NightSleepBuilder(calendar: TestCalendar.paris)
        let wakeDayDST = TestCalendar.day(2026, 10, 25)
        let fixtures: [(day: Date, sleep: [SleepInterval])] = [
            (day, typicalSleep),
            (day, typicalSleep + typicalSleep),
            (day, [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .core),
                   .init(start: d(2026, 11, 20, 1, 0), end: d(2026, 11, 20, 2, 0), stage: .deep),
                   .init(start: d(2026, 11, 19, 22, 30), end: d(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]),
            (day, [SleepInterval(start: d(2026, 11, 19, 18, 5), end: d(2026, 11, 19, 18, 30), stage: .core),
                   .init(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .core)]),
            (day, [SleepInterval(start: d(2026, 11, 20, 1, 0).addingTimeInterval(30), end: d(2026, 11, 20, 1, 30), stage: .deep),
                   .init(start: d(2026, 11, 20, 1, 30), end: d(2026, 11, 20, 2, 0).addingTimeInterval(30), stage: .rem),
                   .init(start: d(2026, 11, 20, 2, 0).addingTimeInterval(30), end: d(2026, 11, 20, 2, 30), stage: .core)]),
            (day, [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]),
            (wakeDayDST, [SleepInterval(start: d(2026, 10, 24, 23, 0), end: d(2026, 10, 25, 7, 0), stage: .core)])
        ]
        for fixture in fixtures {
            let summary = aggregator.night(for: fixture.day, sdnn: [], restingHeartRate: [], sleep: fixture.sleep).sleep
            let night = builder.night(for: fixture.day, sleep: fixture.sleep)
            #expect(summary?.asleepMinutes == night?.asleepMinutes)
            if night?.hasStages == true {
                #expect(summary?.deepMinutes == night?.deepMinutes)
            }
        }
    }

    @Test func dstNightUsesCalendar() {
        // Nuit du 24 au 25 octobre 2026 : retour à l'heure d'hiver, 3 h → 2 h. La nuit dure 9 h réelles.
        let wakeDay = TestCalendar.day(2026, 10, 25)
        let bedtime = d(2026, 10, 24, 23, 0)
        let sleep = [SleepInterval(start: bedtime, end: d(2026, 10, 25, 7, 0), stage: .core)]
        let sdnn = [TimedSample(date: bedtime.addingTimeInterval(3.5 * 3600), value: 55)] // 02:30 heure d'hiver
        let n = aggregator.night(for: wakeDay, sdnn: sdnn, restingHeartRate: [], sleep: sleep)
        #expect(n.sleep?.asleepMinutes == 540)
        #expect(n.sdnnMs == 55)
    }

    @Test func outOfRangeSDNNIgnored() {
        let junk = [TimedSample(date: d(2026, 11, 20, 3, 0), value: 0), .init(date: d(2026, 11, 20, 3, 10), value: 350)]
        let valid = TimedSample(date: d(2026, 11, 20, 3, 20), value: 50)
        #expect(aggregator.night(for: day, sdnn: junk + [valid], restingHeartRate: [], sleep: []).sdnnMs == 50)
        #expect(aggregator.night(for: day, sdnn: junk, restingHeartRate: [], sleep: []).sdnnMs == nil)
    }

    @Test func restingHeartRateOutsideDayIsNil() {
        let rhr = [TimedSample(date: d(2026, 11, 19, 23, 0), value: 49)]
        #expect(aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, sleep: []).restingHeartRate == nil)
    }

    /// Sans sommeil, l'échantillon Apple le plus proche de 8 h : une mise à jour de fin de matinée ne remplace pas celle du matin.
    @Test func restingHeartRateWithoutSleepTakesTheSampleNearestEight() {
        let rhr = [TimedSample(date: d(2026, 11, 20, 8, 0), value: 51), .init(date: d(2026, 11, 20, 10, 0), value: 49)]
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, sleep: [])
        #expect(n.restingHeartRate == 51)
        #expect(n.restingHeartRateSource == .appleNearWake)
    }

    /// Le réveil est à 06:50 : l'échantillon de 07:30 l'emporte sur celui de 11:45, écrit après une marche ou un café.
    @Test func restingHeartRateFallbackTakesTheSampleNearestWake() {
        let rhr = [TimedSample(date: d(2026, 11, 20, 7, 30), value: 52), .init(date: d(2026, 11, 20, 11, 45), value: 60)]
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, sleep: typicalSleep)
        #expect(n.restingHeartRate == 52)
        #expect(n.restingHeartRateSource == .appleNearWake)
    }

    /// Une mesure toutes les 10 minutes pendant le sommeil, de 23:10 à 06:50, plus une mesure aberrante à 30 bpm et des mesures
    /// éveillées plus basses hors du bloc : la FC de repos est le 5e centile des mesures endormies.
    @Test func restingHeartRateIsTheOvernightFifthPercentile() {
        var heartRate = stride(from: 0, to: 460, by: 10).map { minutes in
            TimedSample(date: d(2026, 11, 19, 23, 10).addingTimeInterval(Double(minutes) * 60), value: 52 + Double(minutes % 30) / 10)
        }
        heartRate.append(TimedSample(date: d(2026, 11, 20, 3, 35), value: 40)) // pendant l'éveil de 03:30 à 03:40
        heartRate.append(TimedSample(date: d(2026, 11, 20, 2, 5), value: 30)) // mesure aberrante, endormi
        heartRate.append(TimedSample(date: d(2026, 11, 20, 9, 0), value: 45)) // après le réveil
        let rhr = [TimedSample(date: d(2026, 11, 20, 7, 30), value: 58)]
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, heartRate: heartRate, sleep: typicalSleep)
        #expect(n.restingHeartRate == 52)
        #expect(n.restingHeartRateSource == .overnightLowest)
    }

    @Test func tooFewOvernightHeartRatesFallBackToApple() {
        let heartRate = (0..<4).map { TimedSample(date: d(2026, 11, 20, 1 + $0, 0), value: 50) }
        let rhr = [TimedSample(date: d(2026, 11, 20, 7, 30), value: 55)]
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, heartRate: heartRate, sleep: typicalSleep)
        #expect(n.restingHeartRate == 55)
        #expect(n.restingHeartRateSource == .appleNearWake)
    }

    /// Le score n'est recalculé que jusqu'à midi : sans nouvelle nuit, de nouveaux échantillons de la matinée ne changent rien.
    @Test func lateMorningSamplesDoNotChangeTheNight() {
        let heartRate = (0..<10).map { TimedSample(date: d(2026, 11, 20, 0, 0).addingTimeInterval(Double($0) * 1800), value: 50) }
        let rhr = [TimedSample(date: d(2026, 11, 20, 7, 0), value: 54)]
        let morning = aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, heartRate: heartRate, sleep: typicalSleep)
        let lateHeartRate = heartRate + [TimedSample(date: d(2026, 11, 20, 11, 0), value: 44)]
        let lateRHR = rhr + [TimedSample(date: d(2026, 11, 20, 11, 30), value: 48)]
        let noon = aggregator.night(for: day, sdnn: [], restingHeartRate: lateRHR, heartRate: lateHeartRate, sleep: typicalSleep)
        #expect(morning == noon)
        #expect(noon.restingHeartRate == 50)
    }

    @Test func sdnnSampleCountCountsTheAveragedSamples() {
        #expect(aggregator.night(for: day, sdnn: typicalSDNN, restingHeartRate: [], sleep: typicalSleep).sdnnSampleCount == 3)
        #expect(aggregator.night(for: day, sdnn: [], restingHeartRate: [], sleep: typicalSleep).sdnnSampleCount == nil)
    }

    @Test func nightsBuildsOneSamplePerDay() {
        let days = [TestCalendar.day(2026, 11, 19), day]
        let nights = aggregator.nights(days: days, sdnn: typicalSDNN, restingHeartRate: [], sleep: typicalSleep)
        #expect(nights.map(\.day) == days)
        #expect(nights[0].sleep == nil)
        #expect(nights[1].sleep?.asleepMinutes == 450)
    }
}
