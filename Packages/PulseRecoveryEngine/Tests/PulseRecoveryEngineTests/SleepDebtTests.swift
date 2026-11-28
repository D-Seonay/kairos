import PulseDomain
@testable import PulseRecoveryEngine
import Testing

@Suite struct SleepDebtTests {
    func nights(_ minutes: [Int?]) -> [SleepDebt.Night] {
        minutes.enumerated().compactMap { age, asleep in asleep.map { SleepDebt.Night(age: age, asleepMinutes: $0) } }
    }

    @Test func lastNightCountsInFullAndOlderNightsFade() {
        #expect(SleepDebt.weight(age: 0) == 1)
        #expect(abs((0..<7).reduce(0.0) { $0 + SleepDebt.weight(age: $1) } - 4) < 1e-9)
        // 30 min de moins chaque nuit : 30 × 4.
        #expect(SleepDebt.minutes(nights: nights(Array(repeating: 450, count: 7)), goalMinutes: 480) == 120)
    }

    /// Une seule nuit d'une heure trop courte fait une heure de dette, pas plus.
    @Test func oneShortNightIsNeverMoreThanItsGap() {
        #expect(SleepDebt.minutes(nights: nights([420]), goalMinutes: 480) == 60)
    }

    @Test func recentNightsWeighMore() {
        let lastNightShort = SleepDebt.minutes(nights: nights([420, 480, 480, 480, 480, 480, 480]), goalMinutes: 480)
        let oldNightShort = SleepDebt.minutes(nights: nights([480, 480, 480, 480, 480, 480, 420]), goalMinutes: 480)
        #expect(lastNightShort == 60)
        #expect(oldNightShort == 9) // 60 / 7
    }

    /// Trois nuits de 5 h 30 puis une nuit de 8 h : la dette reste, la dernière nuit n'efface rien.
    @Test func aGoodNightDoesNotEraseThreeShortOnes() {
        let debt = SleepDebt.minutes(nights: nights([480, 330, 330, 330]), goalMinutes: 480)
        #expect(debt == 321) // 150 × (6 + 5 + 4) / 7
        #expect(SleepDebt.score(debtMinutes: debt, goalMinutes: 480) < 40)
    }

    @Test func aSurplusRepaysOnlyHalf() {
        // Dernière nuit 9 h (+60 → −30 à moitié) ; la veille 7 h (60 × 6/7 ≈ 51,4).
        #expect(SleepDebt.minutes(nights: nights([540, 420]), goalMinutes: 480) == 21)
    }

    @Test func theDebtIsNeverNegative() {
        #expect(SleepDebt.minutes(nights: nights([600, 600, 600]), goalMinutes: 480) == 0)
    }

    @Test func nightsWithoutDataCountForNothing() {
        #expect(SleepDebt.minutes(nights: nights([480, nil, nil, 420]), goalMinutes: 480) == 34) // 60 × 4/7
        #expect(SleepDebt.minutes(nights: [], goalMinutes: 480) == 0)
    }

    @Test func nightsOutsideTheWindowAreIgnored() {
        let outside = [SleepDebt.Night(age: 7, asleepMinutes: 0), SleepDebt.Night(age: -1, asleepMinutes: 0)]
        #expect(SleepDebt.minutes(nights: outside, goalMinutes: 480) == 0)
    }

    @Test func theScoreFallsToZeroAtOneFullNightOfDebt() {
        #expect(SleepDebt.score(debtMinutes: 0, goalMinutes: 480) == 100)
        #expect(SleepDebt.score(debtMinutes: 240, goalMinutes: 480) == 50)
        #expect(SleepDebt.score(debtMinutes: 900, goalMinutes: 480) == 0)
    }

    @Test func theSleepFactorIsSeventyPercentLastNightThirtyPercentDebt() {
        #expect(SleepDebt.sleepFactor(lastNightScore: 100, debtScore: 0) == 70)
        #expect(abs(SleepDebt.sleepFactor(lastNightScore: 80, debtScore: 50) - 71) < 1e-9)
    }
}
