import Foundation
import Observation
import PulseContent
import PulseDomain
import PulseServices

/// Ce qui empêche une modification de programme.
public enum ProgramEditorError: Error, Equatable, Sendable {
    /// Aucun programme actif à modifier.
    case noProgram
    /// Pas de profil : le programme actif s'y inscrit.
    case noProfile
    case unknownTemplate
    case unknownProgram
}

/// L'éditeur de programme (spec M4 §11.1) : le programme actif, ses routines, sa semaine type, les autres programmes et les
/// modèles. Chaque modification est enregistrée tout de suite ; celles qui échouent lèvent une erreur et laissent l'état d'avant.
@MainActor
@Observable
public final class ProgramEditorModel {
    static let defaultProgramName = String(localized: "Mon programme", bundle: .module)

    /// Le programme actif, `nil` sans programme actif.
    public private(set) var program: Program?
    /// Les autres programmes non archivés, qu'on peut rendre actifs.
    public private(set) var otherPrograms: [Program] = []
    public let templates: [ProgramTemplate]
    public private(set) var errorMessage: String?

    @ObservationIgnored private let environment: TrainEnvironment

    public init(environment: TrainEnvironment) {
        self.environment = environment
        templates = environment.library.programTemplates
    }

    /// Relit le profil et les programmes. Si une lecture échoue, l'éditeur garde son dernier état et affiche une erreur.
    public func load() async {
        do {
            try await reload()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire tes programmes.", bundle: .module)
        }
    }

    // MARK: - Programme actif

    public func rename(_ name: String) async throws {
        try await update { ProgramEditor.rename($0, to: name, now: $1) }
    }

    /// Place la routine `dayID` (ou un repos, si `nil`) sur `weekday`.
    public func assign(_ dayID: UUID?, to weekday: Weekday) async throws {
        try await update { ProgramEditor.assign(dayID, to: weekday, in: $0, now: $1) }
    }

    /// Ajoute une routine vide en fin de programme et rend son identifiant.
    @discardableResult
    public func addRoutine(named name: String) async throws -> UUID {
        var added: UUID?
        try await update { current, now in
            let result = ProgramEditor.addDay(named: name, exercises: [], to: current, now: now)
            added = result.dayID
            return result.program
        }
        guard let added else { throw ProgramEditorError.noProgram }
        return added
    }

    /// Copie la routine en fin de programme, nommée « … (copie) ».
    public func duplicate(_ dayID: UUID) async throws {
        try await update { ProgramEditor.duplicateDay(id: dayID, in: $0, now: $1) }
    }

    /// Retire la routine du programme et de la semaine type.
    public func remove(_ dayID: UUID) async throws {
        try await update { ProgramEditor.removeDay(id: dayID, from: $0, now: $1) }
    }

    // MARK: - Programmes

    /// Rend `programID` actif. Un programme inconnu ou archivé est refusé.
    public func activate(_ programID: UUID) async throws {
        let profile = try await requireProfile()
        guard let target = try await environment.programs.program(id: programID), !target.isArchived else {
            throw ProgramEditorError.unknownProgram
        }
        try await makeActive(target.id, in: profile)
        try await reload()
    }

    /// Copie le modèle `templateID`, adapté au matériel, aux zones douloureuses et aux jours de repos du profil, puis le rend actif.
    public func adopt(_ templateID: String) async throws {
        let profile = try await requireProfile()
        guard let template = environment.library.programTemplate(id: templateID) else { throw ProgramEditorError.unknownTemplate }
        let adopted = ProgramAdopter(library: environment.library).adopt(
            template, equipment: profile.equipmentAccess, painAreas: profile.painAreas,
            restWeekdays: profile.restWeekdays, now: environment.now())
        try await environment.programs.save(adopted)
        try await makeActive(adopted.id, in: profile)
        try await reload()
    }

    /// Crée un programme vide, nommé « Mon programme » si `name` est vide, puis le rend actif.
    public func createEmpty(named name: String) async throws {
        let profile = try await requireProfile()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let created = ProgramEditor.emptyProgram(name: trimmed.isEmpty ? Self.defaultProgramName : trimmed, now: environment.now())
        try await environment.programs.save(created)
        try await makeActive(created.id, in: profile)
        try await reload()
    }

    /// Archive le programme. S'il était actif, plus aucun programme ne l'est : on en choisit un autre ensuite.
    public func archive(_ programID: UUID) async throws {
        guard var target = try await environment.programs.program(id: programID) else { throw ProgramEditorError.unknownProgram }
        let now = environment.now()
        target.isArchived = true
        target.updatedAt = now
        try await environment.programs.save(target)
        if var profile = try await environment.profiles.load(), profile.activeProgramID == programID {
            profile.activeProgramID = nil
            profile.updatedAt = now
            try await environment.profiles.save(profile)
        }
        try await reload()
    }

    // MARK: - Interne

    private func requireProfile() async throws -> UserProfile {
        guard let profile = try await environment.profiles.load() else { throw ProgramEditorError.noProfile }
        return profile
    }

    private func makeActive(_ programID: UUID, in profile: UserProfile) async throws {
        var updated = profile
        updated.activeProgramID = programID
        updated.updatedAt = environment.now()
        try await environment.profiles.save(updated)
    }

    private func reload() async throws {
        let activeID = try await environment.profiles.load()?.activeProgramID
        let all = try await environment.programs.programs(includeArchived: false)
        if let activeID {
            program = try await environment.programs.program(id: activeID)
        } else {
            program = nil
        }
        otherPrograms = all.filter { $0.id != activeID }
    }

    /// Applique `change` au programme actif et l'enregistre. L'état change avant l'écriture, pour que deux modifications
    /// rapprochées s'enchaînent ; si l'écriture échoue, l'état d'avant revient.
    private func update(_ change: (Program, Date) -> Program) async throws {
        guard let current = program else { throw ProgramEditorError.noProgram }
        let updated = change(current, environment.now())
        program = updated
        do {
            try await environment.programs.save(updated)
        } catch {
            if program == updated { program = current }
            throw error
        }
    }
}
