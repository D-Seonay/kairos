import Foundation
import PhotosFeature
@testable import PlanningFeature
import PulseDomain
import PulseServices
import Testing

/// La section Photos du détail d'une activité : une course Pulse en a une, un entraînement d'Apple Santé non.
@MainActor
struct ActivityDetailPhotosTests {
    @Test func activityDetailHidesPhotosForAppleHealth() async throws {
        let fixture = PlanningFixture(withPhotos: true)
        let health = try await fixture.log(day: 17, hour: 7, kind: .run, meters: 8_200, source: .appleHealth)
        let pulse = try await fixture.log(day: 16, hour: 7, kind: .run, meters: 5_000, source: .pulse)

        let healthModel = ActivityDetailModel(environment: fixture.environment, sessionID: health.id)
        await healthModel.load()
        #expect(healthModel.session != nil)
        #expect(healthModel.photos == nil)

        let pulseModel = ActivityDetailModel(environment: fixture.environment, sessionID: pulse.id)
        #expect(pulseModel.photos == nil)
        // Une photo déjà prise sous l'identifiant de la course se relit par le modèle de la section.
        _ = try await fixture.photos.add(TestImages.jpeg(), to: pulse.id)
        await pulseModel.load()
        let photos = try #require(pulseModel.photos)
        await photos.load()
        #expect(photos.photos.count == 1)
    }

    @Test func activityDetailHasNoPhotosWithoutService() async throws {
        let fixture = PlanningFixture()
        let run = try await fixture.log(day: 16, hour: 7, kind: .run, meters: 5_000, source: .pulse)
        let model = ActivityDetailModel(environment: fixture.environment, sessionID: run.id)
        await model.load()
        #expect(model.session != nil)
        #expect(model.photos == nil)
    }
}
