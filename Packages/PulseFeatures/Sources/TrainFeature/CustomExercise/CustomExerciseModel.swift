import Foundation
import Observation
import PulseContent
import PulseDomain
import PulseServices

public enum CustomExerciseError: Error, Equatable {
    /// Le nom est vide ou un muscle secondaire est aussi le muscle principal.
    case invalid
    /// L'exercice n'existe pas encore : il n'y a rien à archiver.
    case notSaved
}

/// Le formulaire d'un exercice perso : création (vide ou depuis le brouillon de l'import) ou modification (spec M4 §10.3).
@MainActor
@Observable
public final class CustomExerciseModel {
    public var name: String
    public private(set) var primaryMuscle: Muscle
    public var secondaryMuscles: Set<Muscle>
    public private(set) var equipment: Equipment
    public var pattern: MovementPattern
    public private(set) var region: BodyRegion
    public var isUnilateral: Bool
    public var loadKind: LoadKind
    public var incrementKg: Double
    public var restSeconds: Int
    /// Polyarticulaire.
    public var isCompound: Bool
    /// Tenu en secondes (gainage) : la série se note en secondes, pas en répétitions.
    public var tracksDuration: Bool
    public let isEditing: Bool

    @ObservationIgnored private let environment: TrainEnvironment
    @ObservationIgnored private let original: UserExercise?

    /// Un formulaire vide (machine, poussée horizontale, haut du corps, charge externe, 2,5 kg, 90 s), rempli du brouillon `draft`
    /// quand il y en a un, ou de `editing`, l'exercice à modifier, qui l'emporte sur le brouillon.
    public init(environment: TrainEnvironment, draft: UserExerciseDraft?, editing: UserExercise?) {
        self.environment = environment
        original = editing
        isEditing = editing != nil
        let now = environment.now()
        let seed = editing ?? draft?.userExercise(id: UUID(), now: now) ?? Self.blank(now: now)
        name = seed.name
        primaryMuscle = seed.primaryMuscle
        secondaryMuscles = Set(seed.secondaryMuscles)
        equipment = seed.equipment
        pattern = seed.pattern
        region = seed.region
        isUnilateral = seed.isUnilateral
        loadKind = seed.loadKind
        incrementKg = seed.defaultIncrementKg
        restSeconds = seed.defaultRestSeconds
        isCompound = seed.isCompound
        tracksDuration = seed.tracksDuration
    }

    /// Un nom une fois rogné, et des muscles secondaires qui n'incluent pas le principal.
    public var canSave: Bool {
        !trimmedName.isEmpty && !secondaryMuscles.contains(primaryMuscle)
    }

    /// Le muscle principal ; il quitte les muscles secondaires.
    public func setPrimaryMuscle(_ muscle: Muscle) {
        primaryMuscle = muscle
        secondaryMuscles.remove(muscle)
    }

    /// Le matériel ; l'incrément et le repos qui valaient encore la suggestion de l'ancien choix suivent la nouvelle.
    public func setEquipment(_ newValue: Equipment) {
        follow(equipment: newValue, region: region)
    }

    /// La région du corps ; mêmes règles que pour le matériel.
    public func setRegion(_ newValue: BodyRegion) {
        follow(equipment: equipment, region: newValue)
    }

    /// Enregistre l'exercice (nouveau, ou le même `id` s'il est modifié) et le rend.
    public func save() async throws -> UserExercise {
        guard canSave else { throw CustomExerciseError.invalid }
        let now = environment.now()
        let exercise = UserExercise(
            id: original?.id ?? UUID(), name: trimmedName, primaryMuscle: primaryMuscle,
            secondaryMuscles: Muscle.allCases.filter { secondaryMuscles.contains($0) }, equipment: equipment, pattern: pattern,
            region: region, isUnilateral: isUnilateral, defaultIncrementKg: incrementKg, defaultRestSeconds: restSeconds,
            loadKind: loadKind, isCompound: isCompound, tracksDuration: tracksDuration, isArchived: original?.isArchived ?? false,
            createdAt: original?.createdAt ?? now, updatedAt: now)
        try await environment.userExercises.save(exercise)
        return exercise
    }

    /// Archive l'exercice modifié : il n'est plus proposé, mais ses anciennes séries le nomment encore.
    public func archive() async throws {
        guard var exercise = original else { throw CustomExerciseError.notSaved }
        exercise.isArchived = true
        exercise.updatedAt = environment.now()
        try await environment.userExercises.save(exercise)
    }

    // MARK: - Interne

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func blank(now: Date) -> UserExercise {
        UserExercise(name: "", primaryMuscle: .chest, secondaryMuscles: [], equipment: .machine, pattern: .horizontalPush,
                     region: .upper, isUnilateral: false, defaultIncrementKg: suggestedIncrement(.machine, .upper),
                     defaultRestSeconds: suggestedRest(.machine, .upper), createdAt: now, updatedAt: now)
    }

    private func follow(equipment newEquipment: Equipment, region newRegion: BodyRegion) {
        if incrementKg == Self.suggestedIncrement(equipment, region) {
            incrementKg = Self.suggestedIncrement(newEquipment, newRegion)
        }
        if restSeconds == Self.suggestedRest(equipment, region) {
            restSeconds = Self.suggestedRest(newEquipment, newRegion)
        }
        equipment = newEquipment
        region = newRegion
    }

    /// 5 kg pour la barre sur le bas du corps, 2,5 kg ailleurs (le contenu embarqué fait de même).
    private static func suggestedIncrement(_ equipment: Equipment, _ region: BodyRegion) -> Double {
        equipment == .barbell && region == .lower ? 5 : 2.5
    }

    /// 3 min pour la barre sur le bas du corps, 2 min pour la barre ailleurs, 1 min pour le tronc, la poulie, la barre EZ,
    /// l'élastique et le poids du corps, 90 s sinon.
    private static func suggestedRest(_ equipment: Equipment, _ region: BodyRegion) -> Int {
        switch (equipment, region) {
        case (.barbell, .lower): 180
        case (.barbell, _): 120
        case (_, .core), (.cable, _), (.ezBar, _), (.band, _), (.bodyweight, _): 60
        default: 90
        }
    }
}
