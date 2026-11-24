import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// L'appareil photo vu de la section Photos : présent et autorisé, refusé (on propose Réglages) ou absent (simulateur, Mac).
enum CameraAccess {
    enum State: Equatable {
        case available
        case denied
        case unavailable
    }

    /// L'état d'après la présence de l'appareil et l'autorisation. « Pas encore demandé » compte comme disponible : le système
    /// pose la question à la première prise. Sans appareil, l'autorisation ne change rien.
    static func state(isCameraAvailable: Bool, authorization: AVAuthorizationStatus) -> State {
        guard isCameraAvailable else { return .unavailable }
        switch authorization {
        case .denied, .restricted: return .denied
        default: return .available
        }
    }

    /// L'état maintenant. Sur Mac (les tests), l'appareil photo n'existe pas dans l'interface.
    @MainActor
    static func current() -> State {
        state(isCameraAvailable: isCameraAvailable, authorization: AVCaptureDevice.authorizationStatus(for: .video))
    }

    @MainActor
    private static var isCameraAvailable: Bool {
        #if canImport(UIKit)
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #else
        false
        #endif
    }
}
