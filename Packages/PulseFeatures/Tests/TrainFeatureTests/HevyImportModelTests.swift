import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

@MainActor
struct HevyImportModelTests {
    private let fixture = TrainFixture()
    private let triceps = "Extension Triceps Poulie Haute"
    /// Un nom que la table de correspondance ne connaît pas : l'import en propose la création.
    private let unknown = "Curl Inventé Haltère"

    private var environment: TrainEnvironment { fixture.environment }

    private func readFixture() async -> HevyImportModel {
        let model = HevyImportModel(environment: environment)
        await model.read(Data(HevyFixtures.csv.utf8))
        return model
    }

    /// L'extrait, plus une série d'un exercice inconnu dans la séance « Pull ».
    private func readFixtureWithUnknownName() async -> HevyImportModel {
        let model = HevyImportModel(environment: environment)
        let extra = "\"Pull\",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\",\"\",\"\(unknown)\",,\"\",0,\"normal\",12,10,,,"
        await model.read(Data((HevyFixtures.csv + "\n" + extra).utf8))
        return model
    }

    @Test func readingAnExportGoesToTheSummaryWithDefaultChoices() async {
        let model = HevyImportModel(environment: environment)
        await model.read(Data(HevyFixtures.csv.utf8))
        #expect(model.step == .summary)
        #expect(model.choices["Écarté (Machine)"] == .content(id: "pec-deck-machine"))
        #expect(model.ignoredNames.map(\.name) == ["Tapis de Course"])
        #expect(model.canImport)
    }

    @Test func namesAreSplitBetweenSureAndToChoose() async {
        let model = await readFixtureWithUnknownName()
        #expect(model.sureNames.map(\.name).sorted()
                == ["Avant Bras Poulie Barre Droite", "Développé Couché (Barre)", triceps, "Écarté (Machine)"])
        #expect(model.toChooseNames.map(\.name) == [unknown])
        #expect(model.preview?.cardioSetCount == 1)
    }

    @Test func aWrongFileShowsAFrenchMessage() async {
        let model = HevyImportModel(environment: environment)
        await model.read(Data("a,b\n1,2\n".utf8))
        #expect(model.step == .failed("Ce fichier n'est pas un export de séances Hevy."))
        #expect(model.preview == nil)
        #expect(!model.canImport)
    }

    @Test func everyImportErrorHasAFrenchMessage() {
        let model = HevyImportModel(environment: environment)
        #expect(model.message(for: HevyImportError.empty) == "Ce fichier ne contient aucune séance.")
        #expect(model.message(for: HevyImportError.invalidRow(line: 12)) == "La ligne 12 du fichier est illisible.")
        #expect(model.message(for: HevyImportError.invalidDate(line: 1_204))
                == "La date de la ligne 1204 du fichier est illisible.")
        #expect(model.message(for: CocoaError(.fileWriteUnknown)) == "Pulse n'a pas pu importer les séances. Réessaie.")
    }

    @Test func aMalformedRowNamesItsLine() async {
        let model = HevyImportModel(environment: environment)
        let broken = HevyFixtures.csv.replacingOccurrences(of: "\"Pull\",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\"",
                                                           with: "\"Pull\",\"27 Oct 2026\",\"27 Oct 2026, 07:59\"")
        await model.read(Data(broken.utf8))
        guard case .failed(let message) = model.step else { Issue.record("lecture acceptée"); return }
        #expect(message.hasPrefix("La date de la ligne"))
    }

    @Test func aFileThatCannotBeReadShowsAMessage() {
        let model = HevyImportModel(environment: environment)
        model.readingFailed()
        #expect(model.step == .failed("Pulse n'a pas pu lire ce fichier."))
    }

    @Test func importingReportsProgressAndTheResult() async {
        let model = await readFixture()
        model.choose(.content(id: "triceps-pushdown-cable"), for: triceps)
        await model.start()
        guard case .done(let result) = model.step else { Issue.record("import non terminé"); return }
        #expect(result.importedSessions == 2)
        #expect(result.createdExercises == 0)
        #expect(result.records > 0)
    }

    /// Le cardio seul est annoncé au résumé ; le bilan dit aussi les séances restées sans exercice retenu.
    @Test func sessionsLeftOutAreSaid() async {
        let model = HevyImportModel(environment: environment)
        let cardio = "\"Cardio\",\"4 nov. 2026, 10:00\",\"4 nov. 2026, 11:00\",\"\",\"Course\",,\"\",0,\"normal\",,,5,1800,"
        await model.read(Data((HevyFixtures.csv + "\n" + cardio).utf8))
        #expect(model.preview?.newWorkouts.count == 2)
        #expect(model.summaryNotes == ["1 séance de cardio seul non importée",
                                       "Le cardio est proposé en « Ignoré » à l'étape suivante, où tu peux le changer."])
        model.choose(.ignore, for: triceps)
        model.choose(.ignore, for: "Avant Bras Poulie Barre Droite")
        await model.start()
        guard case .done(let result) = model.step else { Issue.record("import non terminé"); return }
        #expect(result.importedSessions == 1)
        #expect(HevyImportModel.resultNotes(for: result)
                == ["1 séance de cardio seul non importée", "1 séance sans exercice retenu non importée"])
        #expect(HevyImportModel.resultNotes(for: HevyImportResult(importedSessions: 4, createdExercises: 0, records: 0,
                                                                  skippedSessions: 2, cardioOnlySessions: 3))
                == ["3 séances de cardio seul non importées", "2 séances sans exercice retenu non importées"])
    }

    @Test func aFileWithNothingToImportSaysWhy() async {
        let model = HevyImportModel(environment: environment)
        let cardio = "\"Cardio\",\"4 nov. 2026, 10:00\",\"4 nov. 2026, 11:00\",\"\",\"Course\",,\"\",0,\"normal\",,,5,1800,"
        let header = HevyFixtures.csv.components(separatedBy: "\n")[0]
        await model.read(Data((header + "\n" + cardio).utf8))
        #expect(!model.canImport)
        #expect(model.summaryNotes == ["1 séance de cardio seul non importée",
                                       "Ce fichier ne contient aucune séance de musculation à importer."])
        await model.read(Data(HevyFixtures.csv.utf8))
        await model.start()
        await model.read(Data(HevyFixtures.csv.utf8))
        #expect(model.summaryNotes == ["Toutes les séances de ce fichier sont déjà dans Pulse : il n'y a rien à ajouter."])
    }

    @Test func importingCreatesTheDefaultCustomExercise() async throws {
        let model = await readFixtureWithUnknownName()
        await model.start()
        guard case .done(let result) = model.step else { Issue.record("import non terminé"); return }
        #expect(result.createdExercises == 1)
        let created = try await environment.userExercises.all(includeArchived: false)
        #expect(created.map(\.name) == [unknown])
    }

    @Test func choosingChangesTheSectionsAndTheChoice() async {
        let model = await readFixture()
        model.choose(.ignore, for: "Écarté (Machine)")
        #expect(model.choices["Écarté (Machine)"] == .ignore)
        #expect(model.ignoredNames.map(\.name).sorted() == ["Tapis de Course", "Écarté (Machine)"])
        #expect(!model.sureNames.map(\.name).contains("Écarté (Machine)"))
        model.restoreProposal(for: "Écarté (Machine)")
        #expect(model.choices["Écarté (Machine)"] == .content(id: "pec-deck-machine"))
    }

    @Test func aGuessedDraftNeedsReviewUntilItIsOpened() async {
        let model = await readFixtureWithUnknownName()
        #expect(model.unresolvedCount == 1)
        #expect(model.needsReview(unknown))
        model.markReviewed(unknown)
        #expect(model.unresolvedCount == 0)
        #expect(!model.needsReview(unknown))
        #expect(model.canImport)
    }

    @Test func aCustomExerciseSavedFromTheFormBecomesTheChoiceAndIsReusedByTheForm() async throws {
        let model = await readFixtureWithUnknownName()
        let form = model.customExerciseModel(for: unknown)
        #expect(form.name == unknown)
        let saved = try await form.save()
        model.didCreate(saved, for: unknown)
        #expect(model.choices[unknown] == .user(id: saved.id))
        #expect(!model.needsReview(unknown))
        #expect(model.label(for: unknown) == unknown)
        #expect(model.customExerciseModel(for: unknown).isEditing)
        await model.start()
        guard case .done(let result) = model.step else { Issue.record("import non terminé"); return }
        #expect(result.createdExercises == 1)
        #expect(try await environment.userExercises.all(includeArchived: false).count == 1)
    }

    @Test func pickingAnExerciseFromTheLibraryMapsItsReference() async {
        let model = await readFixtureWithUnknownName()
        #expect(model.label(for: unknown) == "Créer « \(unknown) »")
        await model.choose(reference: .content(id: "bench-press-barbell"), for: unknown)
        #expect(model.choices[unknown] == .content(id: "bench-press-barbell"))
        #expect(model.label(for: unknown) == "Développé couché à la barre")
        model.restoreProposal(for: unknown)
        #expect(model.label(for: unknown) == "Créer « \(unknown) »")
    }

    @Test func importingTheSameExportAgainOffersNothingNew() async {
        let model = await readFixture()
        await model.start()
        model.restart()
        #expect(model.step == .intro)
        await model.read(Data(HevyFixtures.csv.utf8))
        #expect(model.step == .summary)
        #expect(model.preview?.duplicateCount == 2)
        #expect(!model.canImport)
        await model.start()
        #expect(model.step == .summary)
    }

    @Test func theStepsFollowTheFlow() async {
        let model = await readFixture()
        model.showMapping()
        #expect(model.step == .mapping)
        model.showSummary()
        #expect(model.step == .summary)
    }
}
