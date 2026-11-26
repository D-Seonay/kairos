import Foundation
import Observation
import PulseDomain
import PulseServices

/// Ce qui empêche d'enregistrer une course.
public enum RunDayEditorError: Error, Equatable, Sendable {
    /// Le programme ou la course n'existe plus.
    case missing
}

/// L'éditeur d'un jour de course : son type et son objectif, une durée, une distance ou rien. Comme pour une routine, les
/// modifications se font sur un brouillon : rien n'est enregistré avant `save()`.
@MainActor
@Observable
public final class RunDayEditorModel {
    public private(set) var day: RoutineDay
    /// Vrai une fois la course lue, qu'elle ait été trouvée ou non.
    public private(set) var hasLoaded = false
    /// Vrai si le programme ou le jour est introuvable, ou si le jour n'est pas une course.
    public private(set) var isMissing = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let environment: TrainEnvironment
    @ObservationIgnored private let programID: UUID
    private var saved: RoutineDay
    /// La dernière durée et la dernière distance réglées : passer d'un objectif à l'autre puis revenir ne perd pas la valeur.
    @ObservationIgnored private var lastMinutes = RunDayRules.defaultMinutes
    @ObservationIgnored private var lastKilometres = RunDayRules.defaultKilometres

    public init(environment: TrainEnvironment, programID: UUID, dayID: UUID) {
        self.environment = environment
        self.programID = programID
        let placeholder = RoutineDay(id: dayID, order: 0, name: "", kind: .run)
        day = placeholder
        saved = placeholder
    }

    /// Lit la course. Sans effet une fois lue : le brouillon n'est pas défait. Si la lecture échoue, l'écran affiche une erreur.
    public func load() async {
        guard !hasLoaded else { return }
        do {
            let program = try await environment.programs.program(id: programID)
            if let found = program?.days.first(where: { $0.id == day.id }), found.kind == .run {
                day = found
                saved = found
                remember(goal)
            } else {
                isMissing = true
            }
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette course.", bundle: .module)
        }
    }

    // MARK: - Lecture

    /// Le type de la course ; une course enregistrée sans type se lit comme une sortie facile.
    public var type: RunType {
        day.runType ?? RunDayRules.defaultType
    }

    public var goal: RunGoal {
        RunDayEditor.goal(of: day)
    }

    public var goalKind: RunGoalKind {
        goal.kind
    }

    /// Vrai si le brouillon diffère de ce qui est enregistré.
    public var hasChanges: Bool {
        day != saved
    }

    // MARK: - Brouillon

    /// Change le type : la course prend le nom du nouveau type.
    public func setType(_ type: RunType) {
        day = RunDayEditor.setType(type, in: day)
    }

    /// Passe à un objectif de durée, de distance, ou à aucun, en reprenant la dernière valeur réglée pour cette forme.
    public func setGoalKind(_ kind: RunGoalKind) {
        guard kind != goalKind else { return }
        switch kind {
        case .none: day = RunDayEditor.setGoal(.none, in: day)
        case .duration: day = RunDayEditor.setGoal(.minutes(lastMinutes), in: day)
        case .distance: day = RunDayEditor.setGoal(.kilometres(lastKilometres), in: day)
        }
    }

    public func setMinutes(_ minutes: Int) {
        day = RunDayEditor.setGoal(.minutes(minutes), in: day)
        remember(goal)
    }

    public func setKilometres(_ kilometres: Double) {
        day = RunDayEditor.setGoal(.kilometres(kilometres), in: day)
        remember(goal)
    }

    // MARK: - Enregistrement

    /// Enregistre la course dans son programme, à sa place.
    public func save() async throws {
        guard !isMissing else { throw RunDayEditorError.missing }
        guard let program = try await environment.programs.program(id: programID),
              program.days.contains(where: { $0.id == day.id }) else { throw RunDayEditorError.missing }
        let updated = ProgramEditor.replaceDay(day, in: program, now: environment.now())
        try await environment.programs.save(updated)
        if let stored = updated.days.first(where: { $0.id == day.id }) {
            day = stored
            saved = stored
        }
    }

    private func remember(_ goal: RunGoal) {
        switch goal {
        case .none: break
        case .minutes(let minutes): lastMinutes = minutes
        case .kilometres(let kilometres): lastKilometres = kilometres
        }
    }
}
