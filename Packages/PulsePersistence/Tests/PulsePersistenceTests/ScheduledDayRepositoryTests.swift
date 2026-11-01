import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func scheduledDaysRangeAndDelete() async throws {
    let repo = SwiftDataScheduledDayRepository(modelContainer: try TestContainer.make())
    let first = Sample.scheduledDay(date: Fixed.t0)
    let second = Sample.scheduledDay(date: Fixed.t0.addingTimeInterval(86_400))
    let outside = Sample.scheduledDay(date: Fixed.t0.addingTimeInterval(10 * 86_400))
    for day in [second, outside, first] { try await repo.save(day) }
    let found = try await repo.days(from: Fixed.t0, to: Fixed.t0.addingTimeInterval(7 * 86_400))
    #expect(found.map(\.id) == [first.id, second.id])
    #expect(found[0] .moveReason == .antiInterferenceAfterHeavyLegs)
    var updated = first
    updated.status = .completed
    try await repo.save(updated)
    try await repo.delete(id: second.id)
    let after = try await repo.days(from: .distantPast, to: .distantFuture)
    #expect(after.map(\.id) == [first.id, outside.id] && after[0].status == .completed)
}
