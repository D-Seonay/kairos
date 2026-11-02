#if DEBUG
import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Les données de départ d'un test d'interface (`-PulseSeed`). Sans effet quand un profil existe déjà : au second lancement d'un
/// test qui garde son magasin sur disque, les données du premier lancement restent telles quelles.
struct UITestSeeder: Sendable {
    let profiles: any ProfileRepository
    let programs: any ProgramRepository
    let library: ContentLibrary
    let now: @Sendable () -> Date

    enum SeedError: Error {
        case missingTemplate(String)
    }

    func seed(_ seed: LaunchSeed) async throws {
        guard try await profiles.load() == nil else { return }
        switch seed {
        case .onboardedPPL: try await seedOnboardedPPL()
        }
    }

    /// Un profil terminé et le modèle `ppl-3` adopté comme l'onboarding le fait : mêmes réglages par défaut, même adoption.
    private func seedOnboardedPPL() async throws {
        let date = now()
        var profile = UserProfile(createdAt: date, updatedAt: date)
        profile.onboardingCompletedAt = date
        guard let template = library.programTemplate(id: "ppl-3") else { throw SeedError.missingTemplate("ppl-3") }
        let program = ProgramAdopter(library: library).adopt(
            template, equipment: profile.equipmentAccess, painAreas: profile.painAreas,
            restWeekdays: profile.restWeekdays, now: date)
        try await programs.save(program)
        profile.activeProgramID = program.id
        try await profiles.save(profile)
    }
}

extension AppDependencies {
    /// Crée les données demandées par `-PulseSeed`, avant que la racine ne lise le profil. Jamais dans le magasin réel : il
    /// faut un des magasins des tests d'interface (mémoire ou disque).
    func applyLaunchSeed() async {
        guard let seed = launch.seed, launch.storeInMemory || launch.storeOnDisk else { return }
        let seeder = UITestSeeder(profiles: profiles, programs: programs, library: content, now: now)
        do {
            try await seeder.seed(seed)
        } catch {
            fatalError("Impossible de créer les données de départ du test : \(error)")
        }
    }
}
#endif
