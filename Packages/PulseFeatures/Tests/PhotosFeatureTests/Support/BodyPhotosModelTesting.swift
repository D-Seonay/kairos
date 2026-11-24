import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import Testing

/// Ce que partagent les tests du modèle des photos de corps : un service sur un dépôt en mémoire et une horloge fixe (vendredi 20
/// novembre 2026, midi, à Paris), des photos semées et un modèle déjà déverrouillé.
@MainActor
protocol BodyPhotosModelTesting {
    var service: BodyPhotoService { get }
}

enum BodyPhotosTestText {
    static let unlockReason = "Déverrouille tes photos de corps."
    static let notice = "Sur cet iPhone seulement. Ni iCloud, ni sauvegarde. Exporte-les avant de changer de téléphone."
    static let noPasscode = "Sans code sur cet iPhone, ces photos ne sont ni chiffrées ni verrouillables."
}

extension BodyPhotosModelTesting {
    static func makeService() -> BodyPhotoService {
        BodyPhotoService(store: InMemoryBodyPhotoStore(), measurements: InMemoryBodyMeasurementRepository(),
                         calendar: PhotosTestClock.calendar, timeZone: PhotosTestClock.calendar.timeZone,
                         now: { PhotosTestClock.date("2026-11-20T12:00") })
    }

    func makeModel(_ authentication: StubOwnerAuthentication?,
                   lock: any BodyPhotoLockStore = InMemoryBodyPhotoLockStore()) -> BodyPhotosModel {
        BodyPhotosModel(service: service, authentication: authentication, lock: lock, calendar: PhotosTestClock.calendar,
                        now: { PhotosTestClock.date("2026-11-20T12:00") })
    }

    @discardableResult
    func seed(_ pose: BodyPose, _ date: String) async throws -> BodyPhoto {
        try await service.save(service.process(TestImages.jpeg()), pose: pose, takenAt: PhotosTestClock.date(date))
    }

    /// Un modèle déverrouillé par une authentification réussie.
    func unlockedModel(_ authentication: StubOwnerAuthentication) async -> BodyPhotosModel {
        let model = makeModel(authentication)
        await model.appear()
        return model
    }
}
