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

    @Test func liveDependenciesBuildAContainerOnSimulator() {
        let deps = AppDependencies.live()
        #expect(deps.storeMode == .localOnly || deps.storeMode == .inMemory)
        #expect(deps.storeError == nil)
    }
}
