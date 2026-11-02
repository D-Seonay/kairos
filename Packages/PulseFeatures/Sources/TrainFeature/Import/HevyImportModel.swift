import Foundation
import Observation
import PulseContent
import PulseDomain
import PulseServices

/// Où en est le parcours d'import (spec M4 §13.3).
public enum HevyImportStep: Equatable, Sendable {
    /// L'explication et le choix du fichier.
    case intro
    /// Le fichier est en cours d'analyse.
    case reading
    /// Le résumé de ce que contient le fichier.
    case summary
    /// La correspondance entre les noms de Hevy et les exercices de Pulse.
    case mapping
    /// L'import tourne ; `progress` va de 0 à 1.
    case importing(progress: Double)
    case done(HevyImportResult)
    /// Le message (en français) de ce qui a échoué.
    case failed(String)
}

/// Le parcours d'import de l'historique Hevy : lecture du fichier, résumé, correspondance des noms d'exercice puis import.
/// Chaque nom de l'aperçu a toujours un choix (la proposition de l'import, modifiable) : l'import n'est jamais bloqué.
/// Un exercice perso enregistré depuis le formulaire devient le choix `.user` du nom : il existe alors déjà, et un nouvel import
/// le reprend sans le recréer.
@MainActor
@Observable
public final class HevyImportModel {
    public private(set) var step = HevyImportStep.intro
    public private(set) var preview: HevyImportPreview?
    public private(set) var choices: [String: HevyMappingChoice] = [:]

    private var reviewed: Set<String> = []
    private var createdByForm: [String: UserExercise] = [:]
    private var userExercises: [UserExercise] = []

    @ObservationIgnored private let environment: TrainEnvironment

    public init(environment: TrainEnvironment) {
        self.environment = environment
    }

    /// Vrai quand le résumé ou la correspondance est affiché et que l'export contient des séances nouvelles.
    public var canImport: Bool {
        guard step == .summary || step == .mapping, let preview else { return false }
        return !preview.newWorkouts.isEmpty
    }

    /// Les noms dont l'exercice est un brouillon deviné que l'utilisateur n'a pas encore ouvert. Information seulement : le choix
    /// par défaut reste valable et rien n'est bloqué.
    public var unresolvedCount: Int {
        names.filter { needsReview($0.name) }.count
    }

    /// Les correspondances sûres de la table de noms, tant qu'elles ne sont pas ignorées.
    public var sureNames: [HevyNameSummary] {
        names.filter { $0.isSure && !isIgnored($0.name) }
    }

    /// Les autres noms, à vérifier ou à choisir.
    public var toChooseNames: [HevyNameSummary] {
        names.filter { !$0.isSure && !isIgnored($0.name) }
    }

    public var ignoredNames: [HevyNameSummary] {
        names.filter { isIgnored($0.name) }
    }

    /// « du 3 sept. 2026 au 26 oct. 2026 » ; `nil` sans séance nouvelle.
    public var periodText: String? {
        guard let period = preview?.period else { return nil }
        let (first, last) = (dayText(period.lowerBound), dayText(period.upperBound))
        return first == last ? first : String(localized: "du \(first) au \(last)", bundle: .module)
    }

    // MARK: - Lecture

    /// Analyse l'export `data` : le résumé s'affiche, avec les choix proposés ; sinon, l'échec dit pourquoi.
    public func read(_ data: Data) async {
        step = .reading
        preview = nil
        choices = [:]
        reviewed = []
        createdByForm = [:]
        do {
            let preview = try await environment.importer.preview(data)
            userExercises = (try? await environment.userExercises.all(includeArchived: true)) ?? []
            choices = Dictionary(preview.names.map { ($0.name, $0.choice) }, uniquingKeysWith: { first, _ in first })
            self.preview = preview
            step = .summary
        } catch {
            step = .failed(message(for: error))
        }
    }

    /// Le fichier choisi n'a pas pu être ouvert.
    public func readingFailed() {
        preview = nil
        step = .failed(String(localized: "Pulse n'a pas pu lire ce fichier.", bundle: .module))
    }

    /// Revient au choix du fichier.
    public func restart() {
        preview = nil
        choices = [:]
        step = .intro
    }

    public func showMapping() {
        guard preview != nil else { return }
        step = .mapping
    }

    public func showSummary() {
        guard preview != nil else { return }
        step = .summary
    }

    // MARK: - Correspondance

    public func choose(_ choice: HevyMappingChoice, for name: String) {
        guard choices[name] != nil else { return }
        choices[name] = choice
    }

    /// L'exercice Pulse `reference`, choisi dans la bibliothèque, devient le choix du nom.
    public func choose(reference: ExerciseReference, for name: String) async {
        userExercises = (try? await environment.userExercises.all(includeArchived: true)) ?? userExercises
        switch reference {
        case .content(let id): choose(.content(id: id), for: name)
        case .user(let id): choose(.user(id: id), for: name)
        }
    }

    /// Reprend la proposition de l'import pour `name`.
    public func restoreProposal(for name: String) {
        guard let proposal = preview?.names.first(where: { $0.name == name })?.choice else { return }
        choices[name] = proposal
    }

    /// Le brouillon de `name` a été ouvert : il n'est plus « à vérifier ».
    public func markReviewed(_ name: String) {
        reviewed.insert(name)
    }

    public func needsReview(_ name: String) -> Bool {
        guard case .create(let draft)? = choices[name] else { return false }
        return draft.needsReview && !reviewed.contains(name)
    }

    /// Le formulaire d'exercice perso de `name` : l'exercice déjà créé depuis ce nom s'il y en a un, sinon le brouillon en cours
    /// (ou deviné), à relire.
    public func customExerciseModel(for name: String) -> CustomExerciseModel {
        if let exercise = createdByForm[name] {
            return CustomExerciseModel(environment: environment, draft: nil, editing: exercise)
        }
        var draft = HevyNameGuesser.draft(for: name)
        if case .create(let current)? = choices[name] { draft = current }
        return CustomExerciseModel(environment: environment, draft: draft, editing: nil)
    }

    /// L'exercice perso `exercise`, enregistré depuis le formulaire, devient le choix de `name`.
    public func didCreate(_ exercise: UserExercise, for name: String) {
        createdByForm[name] = exercise
        userExercises.removeAll { $0.id == exercise.id }
        userExercises.append(exercise)
        choose(.user(id: exercise.id), for: name)
    }

    /// La bibliothèque en choix simple, pour associer un exercice Pulse à un nom.
    public func libraryModel() -> LibraryModel {
        LibraryModel(environment: environment, mode: .pick(multiple: false))
    }

    /// Ce que devient `name`, en français : le nom de l'exercice Pulse, « Créer … » ou « Ignoré ».
    public func label(for name: String) -> String {
        let directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
        switch choices[name] {
        case .content(let id)?: return directory.name(of: .content(id: id), fallback: name)
        case .user(let id)?: return directory.name(of: .user(id: id), fallback: name)
        case .create(let draft)?: return String(localized: "Créer « \(draft.name) »", bundle: .module)
        case .ignore?: return String(localized: "Ignoré", bundle: .module)
        case nil: return ""
        }
    }

    // MARK: - Import

    /// Lance l'import et suit sa progression. Sans effet quand `canImport` est faux.
    public func start() async {
        guard canImport, let preview else { return }
        step = .importing(progress: 0)
        let report: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor in self?.report(value) }
        }
        do {
            let result = try await environment.importer.run(preview, choices: choices, progress: report)
            step = .done(HevyImportResult(importedSessions: result.importedSessions,
                                          createdExercises: result.createdExercises + createdByFormInUse,
                                          records: result.records))
        } catch {
            step = .failed(message(for: error))
        }
    }

    /// Le message à montrer pour `error`.
    public func message(for error: any Error) -> String {
        switch error as? HevyImportError {
        case .notHevyExport?:
            String(localized: "Ce fichier n'est pas un export de séances Hevy.", bundle: .module)
        case .empty?:
            String(localized: "Ce fichier ne contient aucune séance.", bundle: .module)
        case .invalidDate(let line)?:
            String(localized: "La date de la ligne \(String(line)) du fichier est illisible.", bundle: .module)
        case .invalidRow(let line)?:
            String(localized: "La ligne \(String(line)) du fichier est illisible.", bundle: .module)
        case nil:
            String(localized: "Pulse n'a pas pu importer les séances. Réessaie.", bundle: .module)
        }
    }

    // MARK: - Interne

    private var names: [HevyNameSummary] {
        preview?.names ?? []
    }

    private func isIgnored(_ name: String) -> Bool {
        choices[name] == .ignore
    }

    /// Les exercices créés depuis le formulaire que l'import utilise encore.
    private var createdByFormInUse: Int {
        createdByForm.filter { choices[$0.key] == .user(id: $0.value.id) }.count
    }

    private func report(_ value: Double) {
        guard case .importing(let current) = step else { return }
        step = .importing(progress: max(current, min(value, 1)))
    }

    private func dayText(_ date: Date) -> String {
        environment.text(of: date) { $0.day().month(.abbreviated).year() }
    }
}
