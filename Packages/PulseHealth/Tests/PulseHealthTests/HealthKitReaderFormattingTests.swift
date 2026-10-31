import Foundation
import HealthKit
@testable import PulseHealth
import Testing

@Suite struct HealthKitReaderFormattingTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test(arguments: [
        (HKCategoryValueSleepAnalysis.asleepDeep, "1 h 30 profond"),
        (.asleepCore, "1 h 30 léger"),
        (.asleepREM, "1 h 30 paradoxal"),
        (.awake, "1 h 30 éveillé"),
        (.inBed, "1 h 30 au lit"),
        (.asleepUnspecified, "1 h 30 endormi")
    ])
    func sleepValueTextIsFrench(value: HKCategoryValueSleepAnalysis, expected: String) {
        let sample = HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: value.rawValue,
                                      start: start, end: start.addingTimeInterval(90 * 60))
        #expect(HealthKitReader.valueText(for: sample, type: .sleepAnalysis) == expected)
    }

    @Test func shortSleepSegmentUsesMinutes() {
        let sample = HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: HKCategoryValueSleepAnalysis.awake.rawValue,
                                      start: start, end: start.addingTimeInterval(3 * 60))
        #expect(HealthKitReader.valueText(for: sample, type: .sleepAnalysis) == "3 min éveillé")
    }
}
