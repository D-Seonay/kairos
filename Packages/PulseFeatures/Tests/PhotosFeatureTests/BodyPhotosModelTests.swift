import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import Testing

/// Le verrou des photos de corps : Face ID à l'apparition, le cache quand la scène n'est plus active, le reverrouillage en
/// arrière-plan et à la sortie de la section.
@MainActor
struct BodyPhotosModelTests: BodyPhotosModelTesting {
    let service = Self.makeService()

    // MARK: Verrou

    @Test func appearAuthenticatesWhenLocked() async throws {
        let photo = try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = makeModel(authentication)
        #expect(model.lockState == .locked)
        await model.appear()
        #expect(authentication.reasons == [BodyPhotosTestText.unlockReason])
        #expect(model.lockState == .unlocked)
        #expect(model.days.map { $0.photos[.front]?.id } == [photo.id])
        #expect(model.thumbnails[photo.id]?.isEmpty == false)
        #expect(model.announcement == "Photos de corps déverrouillées")
        #expect(!model.showsCover)
    }

    @Test func failedAuthenticationStaysLockedAndReadsNothing() async throws {
        let photo = try await seed(.front, "2026-11-01T08:00")
        let model = makeModel(StubOwnerAuthentication(succeeds: false))
        await model.appear()
        #expect(model.lockState == .locked)
        #expect(model.days.isEmpty)
        #expect(model.thumbnails.isEmpty)
        #expect(model.showsCover)
        #expect(await model.image(of: photo.id) == nil)
        #expect(model.photos.isEmpty)
    }

    @Test func unlockRetriesAfterAFailure() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication(succeeds: false)
        let model = makeModel(authentication)
        await model.appear()
        authentication.succeeds = true
        await model.unlock()
        #expect(authentication.reasons.count == 2)
        #expect(model.lockState == .unlocked)
        #expect(model.days.count == 1)
    }

    @Test func lockDisabledSkipsAuthentication() async throws {
        try await seed(.side, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = makeModel(authentication, lock: InMemoryBodyPhotoLockStore(isLockEnabled: false))
        await model.appear()
        #expect(authentication.reasons.isEmpty)
        #expect(model.lockState == .unlocked)
        #expect(!model.isLockEnabled)
        #expect(model.days.count == 1)
    }

    @Test func noPasscodeIsUnavailableAndShowsTheExtraLine() async throws {
        try await seed(.back, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication(available: false)
        let model = makeModel(authentication)
        await model.appear()
        #expect(model.lockState == .unavailable)
        #expect(!model.hasPasscode)
        #expect(!model.isLockEnabled)
        #expect(authentication.reasons.isEmpty)
        #expect(model.days.count == 1)
        #expect(!model.showsCover)
        #expect(model.headerLines.contains(BodyPhotosTestText.noPasscode))
        // L'interrupteur est inactif : le réglage ne bouge pas.
        await model.setLockEnabled(false)
        #expect(authentication.reasons.isEmpty)
    }

    @Test func missingAuthenticatorStaysLocked() async throws {
        let photo = try await seed(.front, "2026-11-01T08:00")
        let model = makeModel(nil, lock: InMemoryBodyPhotoLockStore(isLockEnabled: false))
        await model.appear()
        #expect(model.lockState == .locked)
        #expect(model.hasPasscode)
        #expect(model.showsCover)
        #expect(!model.headerLines.contains(BodyPhotosTestText.noPasscode))
        await model.unlock()
        #expect(model.lockState == .locked)
        #expect(model.days.isEmpty)
        #expect(await model.image(of: photo.id) == nil)
        #expect(await model.exportArchive() == nil)
    }

    @Test func headerGivesTheNoticeAndTheLastShot() async throws {
        try await seed(.front, "2026-10-23T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(model.headerLines == [BodyPhotosTestText.notice, "Dernière prise il y a 4 semaines"])
    }

    @Test func headerWithoutPhotosIsTheNoticeAlone() async {
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(model.headerLines == [BodyPhotosTestText.notice])
    }

    @Test func inactiveScenePhaseShowsCover() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        model.scenePhaseChanged(.inactive)
        #expect(model.isCovered)
        #expect(model.showsCover)
        #expect(model.lockState == .unlocked)
        #expect(model.days.count == 1)
        model.scenePhaseChanged(.active)
        #expect(!model.isCovered)
        #expect(!model.showsCover)
    }

    @Test func backgroundRelocks() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = await unlockedModel(authentication)
        model.scenePhaseChanged(.background)
        #expect(model.lockState == .locked)
        #expect(model.isCovered)
        #expect(model.days.isEmpty)
        #expect(model.thumbnails.isEmpty)
        authentication.succeeds = false
        model.scenePhaseChanged(.inactive)
        model.scenePhaseChanged(.active)
        #expect(model.lockState == .locked)
        await model.pendingUnlock?.value
        #expect(authentication.reasons.count == 2)
        #expect(model.lockState == .locked)
        #expect(model.showsCover)
        // Le retour de l'invite (inactive puis active) ne relance pas une nouvelle demande.
        model.scenePhaseChanged(.inactive)
        model.scenePhaseChanged(.active)
        await model.pendingUnlock?.value
        #expect(authentication.reasons.count == 2)
    }

    @Test func returningFromBackgroundUnlocksAfterANewAuthentication() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = await unlockedModel(authentication)
        model.scenePhaseChanged(.background)
        model.scenePhaseChanged(.active)
        await model.pendingUnlock?.value
        #expect(authentication.reasons.count == 2)
        #expect(model.lockState == .unlocked)
        #expect(model.days.count == 1)
    }

    @Test func backgroundWithTheLockOffCoversWithoutLocking() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let model = makeModel(StubOwnerAuthentication(), lock: InMemoryBodyPhotoLockStore(isLockEnabled: false))
        await model.appear()
        model.scenePhaseChanged(.background)
        #expect(model.isCovered)
        #expect(model.lockState == .unlocked)
        model.scenePhaseChanged(.active)
        #expect(!model.showsCover)
    }

    @Test func disappearRelocksAndForgets() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = await unlockedModel(authentication)
        model.disappear()
        #expect(model.lockState == .locked)
        #expect(model.days.isEmpty)
        #expect(model.thumbnails.isEmpty)
        await model.appear()
        #expect(authentication.reasons.count == 2)
        #expect(model.lockState == .unlocked)
    }

    @Test func leavingEveryScreenRelocksAfterTheGrace() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        model.screenAppeared()
        model.screenDisappeared(grace: .milliseconds(1))
        await model.pendingLeave?.value
        #expect(model.lockState == .locked)
        #expect(model.days.isEmpty)
    }

    @Test func movingBetweenScreensOfTheSectionKeepsTheUnlock() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        model.screenAppeared()
        // La liste disparaît, la comparaison apparaît.
        model.screenDisappeared(grace: .milliseconds(20))
        let leave = model.pendingLeave
        model.screenAppeared()
        await leave?.value
        #expect(model.lockState == .unlocked)
        #expect(model.days.count == 1)
    }

    @Test func appearingAgainWhileUnlockedDoesNotAskAgain() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = await unlockedModel(authentication)
        try await seed(.side, "2026-11-01T08:00")
        await model.appear()
        #expect(authentication.reasons.count == 1)
        #expect(model.days.first?.photos.count == 2)
    }
}
