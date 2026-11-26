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
    }

    /// Les jours de la semaine type du programme, par nature ; `nil` pour un repos.
    private func kinds(_ program: Program) -> [RoutineDayKind?] {
        program.weekLayout.map { id in id.flatMap { id in program.days.first { $0.id == id }?.kind } }
    }

    private func counts(_ program: Program) -> Counts {
        let week = kinds(program)
        return Counts(strength: week.filter { $0 == .strength }.count, runs: week.filter { $0 == .run }.count)
    }

    private func proposal(_ model: OnboardingModel) -> Counts {
        Counts(strength: model.weekProposal.strength, runs: model.weekProposal.runs)
    }

    /// Mène le parcours jusqu'aux objectifs, sans Apple Santé pour une calibration immédiate.
    private func modelAtGoals(_ fixture: OnboardingFixture) async -> OnboardingModel {
        let model = fixture.makeModel()
        await model.start()
        await model.begin()
        await model.skipHealth()
        await model.continueFromProfile()
        return model
    }

    private func adopted(_ fixture: OnboardingFixture) async throws -> Program {
        let programs = try await fixture.programs.programs(includeArchived: true)
        #expect(programs.count == 1)
        return try #require(programs.first)
    }

    @Test func theDefaultProposalIsWhatGetsAdopted() async throws {
        let fixture = OnboardingFixture()
        let model = await modelAtGoals(fixture)
        #expect(model.requestedRuns == 1, "3 séances, curseur au milieu : 2 de musculation et 1 sortie demandées")
        #expect(proposal(model) == Counts(strength: 3, runs: 1), "Full Body garde ses 3 séances, la sortie s'y ajoute")
        let text = OnboardingCopy.proposal(strength: model.weekProposal.strength, runs: model.weekProposal.runs)
        #expect(text == "Proposition : 3 séances de musculation et 1 sortie par semaine.")
        await model.continueFromGoals()
        await model.adoptProgram()
        let program = try await adopted(fixture)
        #expect(program.templateID == "full-body")
        #expect(kinds(program) == [.strength, .run, .strength, nil, .strength, nil, nil])
        let run = try #require(program.days.first { $0.kind == .run })
        #expect(run.runType == .easy && run.runTargetMinutes == 30)
        #expect(program.sessionsPerWeek == 4)
    }

    @Test func theProposalAndTheAdoptedWeekAgreeForEverySliderPosition() async throws {
        let restChoices: [[Weekday]] = [[], [.saturday, .sunday], [.monday, .wednesday, .friday]]
        for rest in restChoices {
            for days in 2...6 {
                for step in 0...10 {
                    let fixture = OnboardingFixture()
                    let model = await modelAtGoals(fixture)
                    model.profile.focus = Double(step) / 10
                    model.profile.trainingDaysPerWeek = days
                    model.profile.restWeekdays = rest
                    let proposed = proposal(model)
                    let text = OnboardingCopy.proposal(strength: proposed.strength, runs: proposed.runs)
                    await model.continueFromGoals()
                    await model.adoptProgram()
                    let program = try await adopted(fixture)
                    let context = Comment(rawValue: "focus \(Double(step) / 10), \(days) séances, repos \(rest.map(\.rawValue))")
                    #expect(counts(program) == proposed, context)
                    #expect(text == OnboardingCopy.proposal(strength: counts(program).strength, runs: counts(program).runs), context)
                    #expect(program.templateID == model.recommendedTemplateID, context)
                    #expect(counts(program).runs >= min(model.requestedRuns, 7 - rest.count), "Aucune sortie perdue : \(context)")
                    for weekday in rest {
                        #expect(program.weekLayout[weekday.index] == nil, "Rien sur un repos obligatoire : \(context)")
                    }
                }
            }
        }
    }

    @Test func movingTheSlidersChangesTheProposalAndTheAdoptedWeekTogether() async throws {
        let fixture = OnboardingFixture()
        let model = await modelAtGoals(fixture)
        await model.continueFromGoals()
        await model.adoptProgram()
        #expect(counts(try await adopted(fixture)) == Counts(strength: 3, runs: 1))

        model.goBack()
        model.goBack()
        #expect(model.step == .goals)
        model.profile.focus = 0.8
        model.profile.trainingDaysPerWeek = 5
        #expect(proposal(model) == Counts(strength: 2, runs: 4), "Renforcement coureur : ses 3 courses, plus une")
        await model.continueFromGoals()
        await model.adoptProgram()
        var program = try await adopted(fixture)
        #expect(program.templateID == "runner-strength" && counts(program) == Counts(strength: 2, runs: 4))

        model.goBack()
        model.goBack()
        model.profile.focus = 0.1
        model.profile.trainingDaysPerWeek = 4
        #expect(model.requestedRuns == 0 && proposal(model) == Counts(strength: 3, runs: 0))
        #expect(OnboardingCopy.proposal(strength: 3, runs: 0) == "Proposition : 3 séances de musculation par semaine.")
        await model.continueFromGoals()
        await model.adoptProgram()
        program = try await adopted(fixture)
        #expect(program.templateID == "ppl-3" && program.days.allSatisfy { $0.kind == .strength })
    }

    @Test func everyTemplateCardPreviewsTheWeekItsAdoptionGives() async throws {
        let fixture = OnboardingFixture()
        let model = await modelAtGoals(fixture)
        model.profile.focus = 0.5
        model.profile.trainingDaysPerWeek = 4
        model.profile.restWeekdays = [.sunday]
        await model.continueFromGoals()
        #expect(model.requestedRuns == 2)
        for template in model.templates {
            let preview = model.weekPreview(for: template).map(\.kind)
            model.selectedTemplateID = template.id
            await model.adoptProgram()
            let week = kinds(try await adopted(fixture)).map { kind -> WeekPreviewDay.Kind in
                switch kind {
                case .strength: .strength
                case .run: .run
                case nil: .rest
                }
            }
            #expect(preview == week, "\(template.id)")
            #expect(preview.filter { $0 == .run }.count >= 2, "\(template.id)")
            model.goBack()
        }
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
