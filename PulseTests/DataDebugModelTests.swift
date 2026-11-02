import Foundation
@testable import Pulse
import PulseDomain
import Testing

@MainActor
@Suite struct DataDebugModelTests {
    @Test func contentSummaryComesFromBundledLibrary() {
        let model = DataDebugModel(dependencies: .testing())
        #expect(model.exerciseCount == 84 && model.templateCount == 5)
        #expect(model.contentVersion == "1.1.0")
        #expect(model.exercisesByPattern.map(\.pattern) == MovementPattern.allCases)
        #expect(model.exerciseName(for: "leg-press-machine") == "Presse à cuisses")
        #expect(model.exerciseName(for: "ghost") == nil)
        #expect(model.templates.map(\.id).first == "ppl-3")
    }

    @Test func seedThenExportThenEraseUpdatesCounts() async {
        let model = DataDebugModel(dependencies: .testing())
        await model.refresh()
        #expect(model.counts[.workoutSets] == 0 && model.storeModeText == "Mémoire")
        await model.seedSampleData()
        #expect(model.counts[.workoutSets] == 9 && model.lastError == nil)
        await model.exportJSON()
        #expect(model.shareURL?.pathExtension == "json")
        await model.exportCSV()
        #expect(model.shareURL?.pathExtension == "zip")
        await model.erase(includeAppleHealth: false)
        #expect(model.didErase && model.counts.values.allSatisfy { $0 == 0 } && model.isBusy == false)
    }

    @Test func eraseFailureStillRefreshesCounts() async {
        struct HealthEraseFailure: Error {}
        let model = DataDebugModel(dependencies: .testing(healthEraser: StubHealthEraser(error: HealthEraseFailure())))
        await model.seedSampleData()
        #expect(model.counts[.workoutSets] == 9)
        await model.erase(includeAppleHealth: true)
        #expect(model.lastError != nil && model.didErase == false && model.isBusy == false)
        #expect(model.counts.values.allSatisfy { $0 == 0 })
    }

    @Test func eraseReportsSuccessBeforeTheRecount() async {
        let model = DataDebugModel(dependencies: .testing(inspector: RecountFailingInspector()))
        await model.refresh()
        #expect(model.lastError == nil)
        await model.erase(includeAppleHealth: false)
        #expect(model.didErase && model.lastError != nil && model.isBusy == false)
    }

    @Test func testingDependenciesUseADedicatedPreferencesSuite() async throws {
        let suite = AppDependencies.testingDefaultsSuite
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(true, forKey: "probe")
        let dependencies = AppDependencies.testing()
        try await dependencies.eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
        #expect(UserDefaults(suiteName: suite)?.object(forKey: "probe") == nil)
    }

    @Test func liveDependenciesBuildAContainerOnSimulator() {
        let deps = AppDependencies.live()
        #expect(deps.storeMode == .localOnly || deps.storeMode == .inMemory)
        #expect(deps.storeError == nil)
    }
}

/// Inspecteur dont le premier comptage réussit et tous les suivants échouent : le recomptage après effacement échoue.
private actor RecountFailingInspector: StoreInspector {
    struct RecountFailure: Error {}

    private var countCalls = 0

    func counts() async throws -> [StoreTable: Int] {
        countCalls += 1
        guard countCalls == 1 else { throw RecountFailure() }
        return [:]
    }

    func cloudAccountStatus() async -> CloudAccountStatus {
        .unknown
    }
}
