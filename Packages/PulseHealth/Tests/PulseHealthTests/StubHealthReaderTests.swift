import Foundation
import PulseDomain
import Testing
@testable import PulseHealth

@Suite struct StubHealthReaderTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    var t1: Date { t0.addingTimeInterval(3600) }
    var t2: Date { t0.addingTimeInterval(7200) }

    @Test func throwsConfiguredErrorFromEveryMethod() async {
        struct Boom: Error {}
        let stub = StubHealthReader(error: Boom())
        await #expect(throws: Boom.self) { try await stub.requestReadAuthorization() }
        await #expect(throws: Boom.self) { try await stub.latestSample(of: .hrvSDNN) }
        await #expect(throws: Boom.self) { try await stub.sampleCount(of: .hrvSDNN, from: t0, to: t2) }
        await #expect(throws: Boom.self) { try await stub.sdnnSamples(from: t0, to: t2) }
        await #expect(throws: Boom.self) { try await stub.restingHeartRateSamples(from: t0, to: t2) }
        await #expect(throws: Boom.self) { try await stub.sleepIntervals(from: t0, to: t2) }
    }

    @Test func seriesAreFilteredOnInclusiveBounds() async throws {
        let sdnn = [TimedSample(date: t0.addingTimeInterval(-1), value: 1), .init(date: t0, value: 2), .init(date: t1, value: 3), .init(date: t2.addingTimeInterval(1), value: 4)]
        let sleep = [SleepInterval(start: t0, end: t1, stage: .core), .init(start: t2, end: t2.addingTimeInterval(60), stage: .core)]
        let stub = StubHealthReader(sdnn: sdnn, restingHeartRate: sdnn, sleep: sleep)
        #expect(try await stub.sdnnSamples(from: t0, to: t1).map(\.value) == [2, 3])
        #expect(try await stub.restingHeartRateSamples(from: t1, to: t2).map(\.value) == [3])
        #expect(try await stub.sleepIntervals(from: t0, to: t1).count == 1)
    }

    @Test func latestAndCountsComeFromConfiguration() async throws {
        let point = HealthSamplePoint(type: .hrvSDNN, date: t0, valueText: "52 ms", sourceName: "Fitbit", sourceBundleID: "com.fitbit.FitbitMobile")
        let stub = StubHealthReader(latest: [.hrvSDNN: point], counts: [.hrvSDNN: 20])
        #expect(try await stub.latestSample(of: .hrvSDNN) == point)
        #expect(try await stub.latestSample(of: .sleepAnalysis) == nil)
        #expect(try await stub.sampleCount(of: .hrvSDNN, from: t0, to: t2) == 20)
        #expect(try await stub.sampleCount(of: .bodyMass, from: t0, to: t2) == 0)
    }

    @Test func dataTypesHaveFrenchTitles() {
        #expect(HealthDataType.allCases.count == 6)
        #expect(HealthDataType.hrvSDNN.title == "VFC (SDNN)")
        #expect(HealthDataType.allCases.allSatisfy { !$0.title.isEmpty })
    }
}
