import Foundation
import PulseDomain
import PulseServices
import Testing

struct HevyNameGuesserTests {
    @Test func guesserReadsMuscleEquipmentAndAssistance() {
        let dips = HevyNameGuesser.draft(for: "Machine Dips Assis")
        #expect(dips.primaryMuscle == .triceps && dips.pattern == .elbowExtension && dips.equipment == .machine)
        let shrug = HevyNameGuesser.draft(for: "Shrug (Haltère)")
        #expect(shrug.primaryMuscle == .traps && shrug.equipment == .dumbbell && shrug.loadKind == .external)
        let pull = HevyNameGuesser.draft(for: "Traction Supination (Assisté)")
        #expect(pull.pattern == .verticalPull && pull.loadKind == .assisted && pull.equipment == .machine)
        #expect(HevyNameGuesser.draft(for: "Leg Curl Assis").pattern == .kneeFlexion)
        #expect(HevyNameGuesser.draft(for: "Oiseau Un Bras (Poulie)").isUnilateral)
    }

    @Test func draftKeepsTheNameAndAlwaysNeedsReview() {
        let draft = HevyNameGuesser.draft(for: "Mouvement Inconnu")
        #expect(draft.name == "Mouvement Inconnu" && draft.needsReview)
        #expect(draft.primaryMuscle == .chest && draft.pattern == .horizontalPush && draft.region == .upper)
        #expect(draft.equipment == .machine && draft.loadKind == .external && !draft.isUnilateral && draft.secondaryMuscles.isEmpty)
    }

    @Test(arguments: [
        ("Poignet Curl (Haltère)", Muscle.forearms, MovementPattern.forearm),
        ("Élévation Latérale (Poulie)", .sideDelts, .shoulderIsolation),
        ("Développé Militaire (Barre)", .frontDelts, .verticalPush),
        ("Curl Jambe Allongé", .hamstrings, .kneeFlexion),
        ("Curl Biceps (Barre EZ)", .biceps, .elbowFlexion),
        ("Pec Deck", .chest, .chestFly),
        ("Développé Incliné (Haltère)", .chest, .horizontalPush),
        ("Tirage Poitrine", .lats, .verticalPull),
        ("Rowing Barre", .upperBack, .horizontalPull),
        ("Soulevé de Terre Roumain", .hamstrings, .hinge),
        ("Leg Extension", .quads, .kneeExtension),
        ("Mollets Debout", .calves, .calfRaise),
        ("Abduction Machine", .abductors, .hipAbduction),
        ("Fentes Marchées", .quads, .lunge),
        ("Presse à Cuisses", .quads, .squat),
        ("Crunch Poulie", .abs, .coreFlexion),
        ("Planche Gainage", .abs, .coreStability)
    ])
    func firstKeywordInTableOrderPicksMusclePattern(name: String, muscle: Muscle, pattern: MovementPattern) {
        let draft = HevyNameGuesser.draft(for: name)
        #expect(draft.primaryMuscle == muscle && draft.pattern == pattern)
    }

    @Test func keywordsMatchWordStartsOnly() {
        // « unilateral » ne contient pas le mot « lateral » : la presse reste une presse.
        #expect(HevyNameGuesser.draft(for: "Presse Unilateral").pattern == .squat)
        #expect(HevyNameGuesser.draft(for: "Presse Unilateral").isUnilateral)
    }

    @Test func equipmentFollowsTheFirstKeywordAndFallsBackToMachine() {
        #expect(HevyNameGuesser.draft(for: "Curl Barre EZ").equipment == .ezBar)
        #expect(HevyNameGuesser.draft(for: "Squat (Barre)").equipment == .barbell)
        #expect(HevyNameGuesser.draft(for: "Squat (Machine Smith)").equipment == .smithMachine)
        #expect(HevyNameGuesser.draft(for: "Écarté Câble").equipment == .cable)
        #expect(HevyNameGuesser.draft(for: "Squat Élastique").equipment == .band)
        #expect(HevyNameGuesser.draft(for: "Presse à Cuisses").equipment == .machine)
        let dips = HevyNameGuesser.draft(for: "Dips Lestés")
        #expect(dips.equipment == .bodyweight && dips.loadKind == .bodyweight)
        #expect(HevyNameGuesser.draft(for: "Traction").equipment == .bodyweight)
    }

    @Test func regionFollowsThePattern() {
        #expect(HevyNameGuesser.draft(for: "Leg Press").region == .lower)
        #expect(HevyNameGuesser.draft(for: "Mollets Assis").region == .lower)
        #expect(HevyNameGuesser.draft(for: "Soulevé de Terre").region == .lower)
        #expect(HevyNameGuesser.draft(for: "Crunch").region == .core)
        #expect(HevyNameGuesser.draft(for: "Curl Biceps").region == .upper)
    }

    @Test func draftBecomesAUserExerciseWithRegionIncrementAndCompoundFlag() {
        let id = UUID()
        let press = HevyNameGuesser.draft(for: "Leg Press").userExercise(id: id, now: .t0)
        #expect(press.id == id && press.name == "Leg Press" && press.createdAt == .t0 && press.updatedAt == .t0)
        #expect(press.defaultIncrementKg == 5 && press.defaultRestSeconds == 90 && press.isCompound)
        #expect(!press.isArchived && !press.tracksDuration)
        let curl = HevyNameGuesser.draft(for: "Curl Biceps").userExercise(id: UUID(), now: .t0)
        #expect(curl.defaultIncrementKg == 2.5 && !curl.isCompound)
        let row = HevyNameGuesser.draft(for: "Rowing Barre").userExercise(id: UUID(), now: .t0)
        #expect(row.isCompound && row.equipment == .barbell)
    }
}
