import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func seederFillsEveryExportedTable() async throws {
    let container = try TestContainer.make()
    try await SampleDataSeeder(container: container).seed(now: Fixed.t0)
    let counts = try await SwiftDataStoreInspector(container: container, cloudEnabled: false).counts()
    for table in StoreTable.allCases where table != .healthQueryAnchors && table != .activeSessionSnapshots {
        #expect((counts[table] ?? 0) > 0, Comment(rawValue: table.rawValue))
    }
    #expect(counts[.workoutSets] == 9 && counts[.dailyRecoveries] == 2 && counts[.supplementIntakes] == 2)
    #expect(counts[.routineDays] == 3 && counts[.routineExercises] == 6 && counts[.cachedHealthSamples] == 3)
    let session = try await SwiftDataWorkoutRepository(modelContainer: container).sessions(from: .distantPast, to: .distantFuture)
    #expect(session.count == 1 && session[0].sets.filter { $0.setType == .warmup }.count == 1)
    #expect(session[0].sets.filter { $0.supersetGroup == 1 }.count == 2)
    #expect(session[0].sets.contains { $0.isMissed })
    #expect(session[0].note == "Dos ok, \"lourd\" aujourd'hui")
}
