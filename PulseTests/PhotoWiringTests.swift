import Foundation
import LocalAuthentication
import PlanningFeature
import ProfileFeature
@testable import Pulse
import RunFeature
import Testing
import TrainFeature

@MainActor
@Suite struct PhotoWiringTests {
    /// Seule l'absence de code ouvre la section sans verrou : une biométrie bloquée ou non configurée retombe sur le code.
    @Test func onlyAMissingPasscodeMakesTheLockUnavailable() {
        let notSet = NSError(domain: LAErrorDomain, code: LAError.Code.passcodeNotSet.rawValue)
        #expect(LocalAuthenticationOwnerAuthenticator.isPasscodeNotSet(notSet))
        for code: LAError.Code in [.biometryLockout, .biometryNotEnrolled, .biometryNotAvailable, .notInteractive] {
            #expect(!LocalAuthenticationOwnerAuthenticator.isPasscodeNotSet(NSError(domain: LAErrorDomain, code: code.rawValue)))
        }
        #expect(!LocalAuthenticationOwnerAuthenticator.isPasscodeNotSet(nil))
        let otherDomain = NSError(domain: NSCocoaErrorDomain, code: LAError.Code.passcodeNotSet.rawValue)
        #expect(!LocalAuthenticationOwnerAuthenticator.isPasscodeNotSet(otherDomain))
    }

    /// Les photos de séance vont à la séance, à la course et au Planning ; les photos de corps arrivent avec leur verrou.
    @Test func environmentsReceiveThePhotoServices() {
        let dependencies = AppDependencies.testing()
        #expect(dependencies.trainEnvironment().sessionPhotos != nil)
        #expect(dependencies.runEnvironment { false }.sessionPhotos != nil)
        #expect(dependencies.planningEnvironment().train.sessionPhotos != nil)
        #expect(dependencies.profileEnvironment().offersBodyPhotos)
    }
}
