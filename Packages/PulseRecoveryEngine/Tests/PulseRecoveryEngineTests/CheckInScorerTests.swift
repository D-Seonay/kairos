import PulseDomain
@testable import PulseRecoveryEngine
import Testing

@Test func checkInAllBest() { #expect(CheckInScorer.score(.init(sleep: 4, pain: 4, motivation: 4)) == 100) }
@Test func checkInWeighted() { #expect(abs(CheckInScorer.score(.init(sleep: 2, pain: 4, motivation: 0)) - 55) < 1e-9) }
@Test func checkInClampsOutOfRange() { #expect(CheckInScorer.score(.init(sleep: 9, pain: -1, motivation: 4)) == 65) }
