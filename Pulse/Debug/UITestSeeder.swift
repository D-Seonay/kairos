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
        guard let template = library.programTemplate(id: "ppl-3") else { return }
        let program = ProgramAdopter(library: library).adopt(
            template, equipment: profile.equipmentAccess, painAreas: profile.painAreas,
            restWeekdays: profile.restWeekdays, now: date)
        try await programs.save(program)
        profile.activeProgramID = program.id
        try await profiles.save(profile)
    }
}

extension AppDependencies {
    /// Crée les données demandées par `-PulseSeed`, avant que la racine ne lise le profil.
    func applyLaunchSeed() async {
        guard let seed = launch.seed else { return }
        let seeder = UITestSeeder(profiles: profiles, programs: programs, library: content, now: now)
        do {
            try await seeder.seed(seed)
        } catch {
            fatalError("Impossible de créer les données de départ du test : \(error)")
        }
    }
}
#endif
