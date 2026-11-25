import Foundation
import LocalAuthentication
import PlanningFeature
import ProfileFeature
@testable import Pulse
import PulseServices
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

    /// L'app réelle et les tests de la cible app gardent le vrai Face ID ; seuls les modes des tests d'interface ont la doublure,
    /// et l'argument `-PulseOwnerAuthentication` seul ne suffit pas.
    @Test func onlyTheUITestModesReplaceFaceID() {
        typealias Photos = AppDependencies.PhotoDependencies
        #expect(AppDependencies.testing().photos.ownerAuthentication is LocalAuthenticationOwnerAuthenticator)
        #expect(Photos.ownerAuthentication(for: LaunchOptions()) is LocalAuthenticationOwnerAuthenticator)
        let argumentOnly = LaunchOptions.parse(["Pulse", "-PulseOwnerAuthentication", "succeeds"])
        #expect(Photos.ownerAuthentication(for: argumentOnly) is LocalAuthenticationOwnerAuthenticator)
        #if DEBUG
        #expect(Photos.ownerAuthentication(for: LaunchOptions(storeInMemory: true)) is UITestOwnerAuthenticator)
        #expect(Photos.ownerAuthentication(for: LaunchOptions(storeOnDisk: true)) is UITestOwnerAuthenticator)
        #endif
    }

    #if DEBUG
    /// La doublure des tests d'interface répond selon `-PulseOwnerAuthentication`, sans demande système.
    @Test func uiTestDoubleFollowsItsScenario() async {
        let succeeds = UITestOwnerAuthenticator(scenario: .succeeds)
        #expect(await succeeds.isAvailable())
        #expect(await succeeds.authenticate(reason: "test"))
        let fails = UITestOwnerAuthenticator(scenario: .fails)
        #expect(await fails.isAvailable())
        #expect(await !fails.authenticate(reason: "test"))
        let noPasscode = UITestOwnerAuthenticator(scenario: .noPasscode)
        #expect(await !noPasscode.isAvailable())
    }
    #endif

    /// Les photos de séance vont à la séance, à la course et au Planning ; les photos de corps arrivent avec leur verrou.
    @Test func environmentsReceiveThePhotoServices() {
        let dependencies = AppDependencies.testing()
        #expect(dependencies.trainEnvironment().sessionPhotos != nil)
        #expect(dependencies.runEnvironment { false }.sessionPhotos != nil)
        #expect(dependencies.planningEnvironment().train.sessionPhotos != nil)
        #expect(dependencies.profileEnvironment().offersBodyPhotos)
    }
}
