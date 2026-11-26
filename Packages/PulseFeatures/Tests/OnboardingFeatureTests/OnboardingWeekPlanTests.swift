import Foundation
@testable import OnboardingFeature
import PulseContent
import PulseDomain
import PulseServices
import Testing

/// La proposition de l'étape des objectifs et la semaine adoptée : le même plan, lu deux fois.
@MainActor
struct OnboardingWeekPlanTests {
    private struct Counts: Equatable {
        var strength: Int
        var runs: Int

        var sessions: Int { strength + runs }
    }

    /// Les jours de la semaine type du programme, par nature ; `nil` pour un repos.
    private func kinds(_ program: Program) -> [RoutineDayKind?] {
        program.weekLayout.map { id in id.flatMap { id in program.days.first { $0.id == id }?.kind } }
    }

    private func names(_ program: Program) -> [String?] {
        program.weekLayout.map { id in id.flatMap { id in program.days.first { $0.id == id }?.name } }
    }

    private func counts(_ program: Program) -> Counts {
        let week = kinds(program)
        return Counts(strength: week.filter { $0 == .strength }.count, runs: week.filter { $0 == .run }.count)
    }

    private func proposal(_ model: OnboardingModel) -> Counts {
        Counts(strength: model.weekProposal.strength, runs: model.weekProposal.runs)
    }

    private func text(_ counts: Counts) -> String {
        OnboardingCopy.proposal(strength: counts.strength, runs: counts.runs)
    }

    /// Mène le parcours jusqu'aux objectifs, sans Apple Santé pour une calibration immédiate.
    private func modelAtGoals(_ fixture: OnboardingFixture, focus: Double = 0.5, days: Int = 3,
                              rest: [Weekday] = []) async -> OnboardingModel {
        let model = fixture.makeModel()
        await model.start()
        await model.begin()
        await model.skipHealth()
        await model.continueFromProfile()
        model.profile.focus = focus
        model.profile.trainingDaysPerWeek = days
        model.profile.restWeekdays = rest
        return model
    }

    private func adopted(_ fixture: OnboardingFixture) async throws -> Program {
        let programs = try await fixture.programs.programs(includeArchived: true)
        #expect(programs.count == 1)
        return try #require(programs.first)
    }

    /// Le modèle copié tel quel, sans le partage du curseur : ce que « entier » veut dire pour ces jours de repos.
    private func whole(_ templateID: String?, rest: [Weekday]) throws -> Program {
        let template = try #require(ContentLibrary.bundled.programTemplates.first { $0.id == templateID })
        return ProgramAdopter(library: .bundled).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: rest,
                                                       now: OnboardingClock.now)
    }

    @Test func theDefaultProposalIsWhatGetsAdopted() async throws {
        let fixture = OnboardingFixture()
        let model = await modelAtGoals(fixture)
        #expect(model.requestedRuns == 1, "3 séances, curseur au milieu : 2 de musculation et 1 sortie")
        #expect(proposal(model) == Counts(strength: 2, runs: 1))
        #expect(text(proposal(model)) == "Proposition : 2 séances de musculation et 1 sortie par semaine.")
        await model.continueFromGoals()
        await model.adoptProgram()
        let program = try await adopted(fixture)
        #expect(program.templateID == "full-body")
        // Lundi, mercredi, vendredi : la semaine raccourcie reste étalée.
        #expect(names(program) == ["Full Body A", nil, "Sortie facile", nil, "Full Body B", nil, nil])
        #expect(program.days.map(\.name) == ["Full Body A", "Full Body B", "Full Body C", "Sortie facile"],
                "Full Body C reste dans le programme, à placer plus tard")
        let run = try #require(program.days.first { $0.kind == .run })
        #expect(run.runType == .easy && run.runTargetMinutes == 30)
        #expect(program.sessionsPerWeek == 3)
    }

    /// Les semaines attendues, sans repos obligatoire : jamais plus de séances que demandé, un split jamais entamé.
    @Test func theAdoptedWeekFollowsTheSessionsAsked() async throws {
        struct Expected {
            var focus: Double
            var days: Int
            var template: String
            var week: Counts
            var text: String
        }
        let table = [
            Expected(focus: 0.5, days: 3, template: "full-body", week: Counts(strength: 2, runs: 1),
                     text: "Proposition : 2 séances de musculation et 1 sortie par semaine."),
            Expected(focus: 0.5, days: 4, template: "full-body", week: Counts(strength: 2, runs: 2),
                     text: "Proposition : 2 séances de musculation et 2 sorties par semaine."),
            Expected(focus: 0.5, days: 5, template: "full-body", week: Counts(strength: 3, runs: 2),
                     text: "Proposition : 3 séances de musculation et 2 sorties par semaine."),
            Expected(focus: 0.5, days: 6, template: "full-body", week: Counts(strength: 3, runs: 3),
                     text: "Proposition : 3 séances de musculation et 3 sorties par semaine."),
            Expected(focus: 0.2, days: 3, template: "ppl-3", week: Counts(strength: 3, runs: 0),
                     text: "Proposition : 3 séances de musculation par semaine."),
            Expected(focus: 0.2, days: 4, template: "ppl-3", week: Counts(strength: 3, runs: 1),
                     text: "Proposition : 3 séances de musculation et 1 sortie par semaine."),
            Expected(focus: 0.2, days: 6, template: "ppl-6", week: Counts(strength: 6, runs: 0),
                     text: "Proposition : 6 séances de musculation par semaine.")
        ]
        for expected in table {
            let fixture = OnboardingFixture()
            let model = await modelAtGoals(fixture, focus: expected.focus, days: expected.days)
            let context = Comment(rawValue: "curseur \(expected.focus), \(expected.days) séances")
            #expect(proposal(model) == expected.week, context)
            #expect(text(proposal(model)) == expected.text, context)
            await model.continueFromGoals()
            await model.adoptProgram()
            let program = try await adopted(fixture)
            #expect(program.templateID == expected.template, context)
            #expect(counts(program) == expected.week, context)
        }
    }

    /// Le curseur demande une sortie, mais Push / Pull / Legs remplit déjà les 3 séances : la proposition n'en promet pas.
    @Test func aRunThatDoesNotFitIsNotPromised() async throws {
        let fixture = OnboardingFixture()
        let model = await modelAtGoals(fixture, focus: 0.2, days: 3)
        #expect(model.requestedRuns == 1)
        #expect(!text(proposal(model)).contains("sortie"))
        await model.continueFromGoals()
        await model.adoptProgram()
        let program = try await adopted(fixture)
        #expect(names(program) == ["Push", nil, "Pull", nil, "Legs", nil, nil])
        #expect(program.days.allSatisfy { $0.kind == .strength })
    }

    @Test func theProposalAndTheAdoptedWeekAgreeForEverySliderPosition() async throws {
        let restChoices: [[Weekday]] = [[], [.saturday, .sunday], [.monday, .wednesday, .friday]]
        for rest in restChoices {
            for days in 2...6 {
                for step in 0...10 {
                    let fixture = OnboardingFixture()
                    let model = await modelAtGoals(fixture, focus: Double(step) / 10, days: days, rest: rest)
                    let proposed = proposal(model)
                    await model.continueFromGoals()
                    await model.adoptProgram()
                    let program = try await adopted(fixture)
                    let context = Comment(rawValue: "curseur \(Double(step) / 10), \(days) séances, repos \(rest.map(\.rawValue))")
                    let week = counts(program)
                    #expect(week == proposed, context)
                    #expect(text(proposed) == text(week), context)
                    #expect(program.templateID == model.recommendedTemplateID, context)
                    try expectRules(program, model: model, days: days, rest: rest, context: context)
                }
            }
        }
    }

    /// Les règles de la semaine adoptée : pas plus de séances que demandé (sauf le modèle seul), rien sur un repos obligatoire,
    /// un modèle qui ne se raccourcit pas adopté entier, et pas plus de sorties que le curseur ou le modèle n'en comptent.
    private func expectRules(_ program: Program, model: OnboardingModel, days: Int, rest: [Weekday], context: Comment) throws {
        let week = counts(program)
        let template = try #require(ContentLibrary.bundled.programTemplates.first { $0.id == program.templateID })
        let whole = try whole(program.templateID, rest: rest)
        let own = counts(whole)
        #expect(week.sessions <= days || week.sessions == own.sessions, "Pas plus de séances que demandé : \(context)")
        if week.sessions > days {
            #expect(names(program) == names(whole), "Un modèle déjà au-dessus de la demande reste tel quel : \(context)")
        }
        for weekday in rest {
            #expect(program.weekLayout[weekday.index] == nil, "Rien sur un repos obligatoire : \(context)")
        }
        if template.canBeShortened {
            let asked = max(1, days - model.requestedRuns)
            #expect(week.strength == min(own.strength, asked), "Les premières routines seulement : \(context)")
        } else {
            for (index, name) in names(whole).enumerated() where name != nil {
                #expect(names(program)[index] == name, "Un modèle entier ne perd aucune séance : \(context)")
            }
        }
        #expect(week.runs >= own.runs && week.runs <= max(own.runs, model.requestedRuns), "Les sorties : \(context)")
        #expect(program.days.filter { $0.kind == .strength }.count == template.days.filter { $0.kind == .strength }.count,
                "Aucune routine ne quitte le programme : \(context)")
    }

    @Test func movingTheSlidersChangesTheProposalAndTheAdoptedWeekTogether() async throws {
        let fixture = OnboardingFixture()
        let model = await modelAtGoals(fixture)
        await model.continueFromGoals()
        await model.adoptProgram()
        #expect(counts(try await adopted(fixture)) == Counts(strength: 2, runs: 1))

        model.goBack()
        model.goBack()
        #expect(model.step == .goals)
        model.profile.focus = 0.8
        model.profile.trainingDaysPerWeek = 5
        #expect(model.requestedRuns == 4)
        #expect(proposal(model) == Counts(strength: 2, runs: 3), "Renforcement coureur remplit déjà les 5 séances")
        model.profile.trainingDaysPerWeek = 6
        #expect(proposal(model) == Counts(strength: 2, runs: 4), "Une séance de plus : une sortie de plus")
        await model.continueFromGoals()
        await model.adoptProgram()
        var program = try await adopted(fixture)
        #expect(program.templateID == "runner-strength" && counts(program) == Counts(strength: 2, runs: 4))

        model.goBack()
        model.goBack()
        model.profile.focus = 0.1
        model.profile.trainingDaysPerWeek = 4
        #expect(model.requestedRuns == 0 && proposal(model) == Counts(strength: 3, runs: 0))
        await model.continueFromGoals()
        await model.adoptProgram()
        program = try await adopted(fixture)
        #expect(program.templateID == "ppl-3" && program.days.allSatisfy { $0.kind == .strength })
    }

    @Test func everyTemplateCardPreviewsTheWeekItsAdoptionGives() async throws {
        let fixture = OnboardingFixture()
        let rest: [Weekday] = [.sunday]
        let model = await modelAtGoals(fixture, focus: 0.5, days: 4, rest: rest)
        await model.continueFromGoals()
        #expect(model.requestedRuns == 2)
        for template in model.templates {
            let preview = model.weekPreview(for: template).map(\.kind)
            model.selectedTemplateID = template.id
            await model.adoptProgram()
            let program = try await adopted(fixture)
            let week = kinds(program).map { kind -> WeekPreviewDay.Kind in
                switch kind {
                case .strength: .strength
                case .run: .run
                case nil: .rest
                }
            }
            #expect(preview == week, "\(template.id)")
            try expectRules(program, model: model, days: 4, rest: rest, context: Comment(rawValue: template.id))
            model.goBack()
        }
    }

    /// La carte d'un modèle raccourci dit ce qui reste de côté ; celle d'un modèle entier ne dit rien.
    @Test func aShortenedTemplateSaysWhatStaysOutOfTheWeek() async throws {
        let model = await modelAtGoals(OnboardingFixture())
        let templates = ContentLibrary.bundled.programTemplates
        let fullBody = try #require(templates.first { $0.id == "full-body" })
        let split = try #require(templates.first { $0.id == "ppl-3" })
        #expect(model.weekPlan(for: fullBody).unplacedRoutines == 1)
        #expect(model.weekPlan(for: split).unplacedRoutines == 0)
        #expect(OnboardingCopy.unplacedRoutines(0) == nil)
        #expect(OnboardingCopy.unplacedRoutines(1) == "1 routine reste hors de la semaine : tu pourras la placer plus tard.")
        #expect(OnboardingCopy.unplacedRoutines(2) == "2 routines restent hors de la semaine : tu pourras les placer plus tard.")
        #expect(OnboardingCopy.runsPlacement(sessions: 3)
            == "Tes sorties sont placées quand il reste un jour libre, sans dépasser tes 3 séances par semaine.")
    }

    @Test func aCustomProgramAdoptsNothingWhateverTheProposal() async throws {
        let fixture = OnboardingFixture()
        let model = await modelAtGoals(fixture)
        await model.continueFromGoals()
        model.choseCustomProgram = true
        await model.adoptProgram()
        #expect(try await fixture.programs.programs(includeArchived: true).isEmpty)
    }
}
