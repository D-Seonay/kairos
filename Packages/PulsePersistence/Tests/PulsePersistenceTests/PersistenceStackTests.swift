import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func inMemoryContainerBuildsWithMigrationPlanAndBothConfigurations() throws {
    let container = try TestContainer.make()
    #expect(container.configurations.count == 2)
    #expect(PulseSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    #expect(PulseSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
    #expect(PulseMigrationPlan.schemas.count == 2 && PulseMigrationPlan.stages.count == 1)
    let context = ModelContext(container)
    context.insert(StoredProfile(UserProfile()))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<StoredProfile>()) == 1)
}
