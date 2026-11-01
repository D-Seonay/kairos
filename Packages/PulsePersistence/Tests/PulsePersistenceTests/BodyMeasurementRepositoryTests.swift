import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func bodyMeasurementsByDate() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    let later = Sample.measurement(date: Fixed.t0.addingTimeInterval(86_400))
    let earlier = Sample.measurement(date: Fixed.t0)
    let outside = Sample.measurement(date: Fixed.t0.addingTimeInterval(86_400 * 9))
    for measurement in [later, earlier, outside] { try await repo.save(measurement) }
    #expect(try await repo.measurements(from: Fixed.t0, to: Fixed.t0.addingTimeInterval(86_400 * 7)).map(\.id) == [earlier.id, later.id])
    var updated = earlier
    updated.weightKg = 77
    try await repo.save(updated)
    try await repo.delete(id: later.id)
    let all = try await repo.measurements(from: .distantPast, to: .distantFuture)
    #expect(all.map(\.id) == [earlier.id, outside.id] && all[0].weightKg == 77)
}
