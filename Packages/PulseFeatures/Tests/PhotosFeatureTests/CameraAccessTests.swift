import AVFoundation
@testable import PhotosFeature
import Testing

struct CameraAccessTests {
    @Test func noCameraMeansUnavailableWhateverTheAuthorisation() {
        #expect(CameraAccess.state(isCameraAvailable: false, authorization: .authorized) == .unavailable)
        #expect(CameraAccess.state(isCameraAvailable: false, authorization: .denied) == .unavailable)
    }

    @Test func deniedAndRestrictedAreDenied() {
        #expect(CameraAccess.state(isCameraAvailable: true, authorization: .denied) == .denied)
        #expect(CameraAccess.state(isCameraAvailable: true, authorization: .restricted) == .denied)
    }

    @Test func authorisedAndUndeterminedAreAvailable() {
        #expect(CameraAccess.state(isCameraAvailable: true, authorization: .authorized) == .available)
        #expect(CameraAccess.state(isCameraAvailable: true, authorization: .notDetermined) == .available)
    }
}
