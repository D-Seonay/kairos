import Foundation
import Observation
import PulseContent
import PulseDomain
import PulseServices

/// Ce que fait un toucher dans la bibliothèque.
public enum LibraryMode: Equatable, Sendable {
    /// Consultation : toucher une ligne ouvre la fiche.
    case browse
    /// Choix : toucher une ligne la (dé)sélectionne ; `multiple` autorise plusieurs exercices.
    case pick(multiple: Bool)
}

/// La bibliothèque d'exercices : le contenu non retiré et les exercices perso non archivés, recherchés et filtrés (spec M4 §10.1).
@MainActor
@Observable
public final class LibraryModel {
    /// Un exercice est « récent » quand il a été fait durant les 30 derniers jours.
    private static let recentDays = 30

    public let mode: LibraryMode
    public var query = ""
    public var group: MuscleGroup?
    public var equipment: Equipment?
    public private(set) var errorMessage: String?
    /// Les exercices choisis, dans l'ordre des touches.
    private var selectionOrder: [ExerciseReference] = []
    private var exercises: [ExerciseInfo]
    private var recent: [ExerciseReference] = []
    private var recentSet: Set<ExerciseReference> = []
    private var oneRepMaxes: [ExerciseReference: Double] = [:]

    @ObservationIgnored private let environment: TrainEnvironment

    public init(environment: TrainEnvironment, mode: LibraryMode) {
        self.environment = environment
        self.mode = mode
        exercises = ExerciseDirectory(library: environment.library, userExercises: []).active
    }

    /// Les exercices qui répondent à la recherche et aux filtres : les récents d'abord, puis l'ordre alphabétique.
    public var results: [ExerciseInfo] {
        ExerciseBrowser.results(exercises, query: query, group: group, equipment: equipment, recent: recent)
    }

    public var selection: Set<ExerciseReference> {
        Set(selectionOrder)
    }

    public func isRecent(_ reference: ExerciseReference) -> Bool {
        recentSet.contains(reference)
    }

    /// Le 1RM estimé actuel de l'exercice d'après ses records ; `nil` sans record.
    public func oneRepMax(for reference: ExerciseReference) -> Double? {
        oneRepMaxes[reference]
    }

    /// Relit les exercices de l'utilisateur, les séances récentes et les records. Chaque lecture qui échoue laisse l'état précédent
    /// en place et affiche une erreur.
    public func load() async {
        let userExercises = try? await environment.userExercises.all(includeArchived: false)
        let sessions = try? await environment.workouts.sessions(from: recentStart() ?? .distantPast, to: .distantFuture)
        let records = try? await environment.personalRecords.records(for: nil)
        if let userExercises {
            exercises = ExerciseDirectory(library: environment.library, userExercises: userExercises).active
        }
        if let sessions {
            recent = RecentExercises.references(in: sessions, now: environment.now(), calendar: environment.calendar,
                                                days: Self.recentDays)
            recentSet = Set(recent)
        }
        if let records {
            oneRepMaxes = Dictionary(grouping: records.filter { $0.kind == .estimatedOneRepMax }, by: \.exercise)
                .compactMapValues { $0.map(\.value).max() }
        }
        let failed = userExercises == nil || sessions == nil || records == nil
        errorMessage = failed ? String(localized: "Pulse n'a pas pu lire toute la bibliothèque.", bundle: .module) : nil
    }

    /// Ajoute l'exercice au choix, ou l'en retire. Sans effet en consultation ; en choix unique, il remplace le précédent.
    public func toggle(_ reference: ExerciseReference) {
        guard case .pick(let multiple) = mode else { return }
        if let index = selectionOrder.firstIndex(of: reference) {
            selectionOrder.remove(at: index)
        } else if multiple {
            selectionOrder.append(reference)
        } else {
            selectionOrder = [reference]
        }
    }

    /// Les exercices choisis, dans l'ordre des touches.
    public func confirm() -> [ExerciseReference] {
        selectionOrder
    }

    /// La fiche d'un exercice de la bibliothèque.
    public func sheet(for reference: ExerciseReference) -> ExerciseSheetModel {
        ExerciseSheetModel(environment: environment, reference: reference)
    }

    /// Le formulaire de création d'un exercice perso.
    public func creator() -> CustomExerciseModel {
        CustomExerciseModel(environment: environment, draft: nil, editing: nil)
    }

    private func recentStart() -> Date? {
        environment.calendar.date(byAdding: .day, value: -Self.recentDays, to: environment.now())
    }
}
