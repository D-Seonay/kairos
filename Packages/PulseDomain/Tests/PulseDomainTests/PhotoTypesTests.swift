import Foundation
@testable import PulseDomain
import Testing

@Suite("Types de photos du domaine")
struct PhotoTypesTests {
    @Test("les poses s'affichent dans l'ordre face, profil, dos")
    func bodyPosesAreOrderedFrontSideBack() {
        #expect(BodyPose.allCases == [.front, .side, .back])
    }

    @Test("une photo de séance survit à un aller-retour JSON")
    func sessionPhotoRoundTripsThroughJSON() throws {
        let photo = SessionPhoto(
            id: UUID(), sessionID: UUID(), order: 2,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let data = try JSONEncoder().encode(photo)
        let decoded = try JSONDecoder().decode(SessionPhoto.self, from: data)
        #expect(decoded == photo)
    }

    @Test("une séance accepte six photos au plus")
    func maxPerSessionIsSix() {
        #expect(SessionPhoto.maxPerSession == 6)
    }
}
