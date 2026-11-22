// swiftlint:disable force_unwrapping
import Foundation
import PulseDomain
import PulseServices
@testable import SupplementsFeature
import Testing

/// Les textes dits des compléments : dose en toutes lettres, heure parlée, annonce d'une prise. Jamais « UI », « mg », « µg »
/// ni « 8:00 ».
@MainActor
struct SupplementsSpokenTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private let now = DateComponents(calendar: Self.calendar, timeZone: Self.calendar.timeZone, year: 2026, month: 11, day: 20,
                                     hour: 9).date!

    private func supplement(_ name: String = "Vitamine D3", dose: Double, unit: DoseUnit, timing: SupplementTiming = .fixedTime,
                            minutes: Int? = 480) -> Supplement {
        Supplement(name: name, form: .capsule, dose: dose, unit: unit, timing: timing, timeOfDayMinutes: minutes, days: .everyDay,
                   order: 0, createdAt: now, updatedAt: now)
    }

    private func item(_ supplement: Supplement, taken: Bool = false, workoutFinished: Bool = false,
                      plannedMinutes: Int = 480) -> SupplementDueItem {
        let intake = taken
            ? SupplementIntake(supplementID: supplement.id, takenAt: now, dose: supplement.dose, createdAt: now, updatedAt: now)
            : nil
        return SupplementDueItem(supplement: supplement, moment: .morning, plannedMinutes: plannedMinutes, intake: intake,
                                 isWorkoutFinished: workoutFinished)
    }

    @Test func detailIsSpokenWithUnitWordsAndClock() {
        let thousand = SupplementText.number(1_000)
        #expect(SupplementsModel.detailSpoken(item(supplement(dose: 1_000, unit: .iu)))
            == "\(thousand) unités internationales, à 8 heures")
        #expect(SupplementsModel.detailSpoken(item(supplement(dose: 5, unit: .gram), plannedMinutes: 8 * 60 + 30))
            == "5 grammes, à 8 heures 30")
        #expect(SupplementsModel.detailSpoken(item(supplement(dose: 1, unit: .gram))) == "1 gramme, à 8 heures")
        #expect(SupplementsModel.detailSpoken(item(supplement(dose: 200, unit: .mg))) == "200 milligrammes, à 8 heures")
        #expect(SupplementsModel.detailSpoken(item(supplement(dose: 25, unit: .microgram))) == "25 microgrammes, à 8 heures")
        #expect(SupplementsModel.detailSpoken(item(supplement(dose: 1.5, unit: .ml))) == "1,5 millilitre, à 8 heures")
        #expect(SupplementsModel.detailSpoken(item(supplement(dose: 2, unit: .serving))) == "2 doses, à 8 heures")
    }

    @Test func detailSaysWhenTheIntakeFollowsTheWorkoutOrBedtime() {
        let before = supplement(dose: 200, unit: .mg, timing: .beforeWorkout, minutes: nil)
        #expect(SupplementsModel.detailSpoken(item(before, plannedMinutes: 17 * 60 + 30))
            == "200 milligrammes, à 17 heures 30, 30 minutes avant la séance")
        let after = supplement(dose: 30, unit: .gram, timing: .afterWorkout, minutes: nil)
        #expect(SupplementsModel.detailSpoken(item(after, workoutFinished: false)) == "30 grammes, après la séance")
        #expect(SupplementsModel.detailSpoken(item(after, workoutFinished: true, plannedMinutes: 18 * 60 + 15))
            == "30 grammes, à 18 heures 15, après la séance")
        let bed = supplement(dose: 400, unit: .mg, timing: .bedtime, minutes: 22 * 60 + 30)
        #expect(SupplementsModel.detailSpoken(item(bed, plannedMinutes: 22 * 60 + 30))
            == "400 milligrammes, à 22 heures 30, au coucher")
    }

    @Test func notDueDetailUsesTheDays() {
        let thousand = SupplementText.number(1_000)
        #expect(SupplementsModel.notDueSpoken(supplement(dose: 1_000, unit: .iu), days: "Jours d'entraînement")
            == "\(thousand) unités internationales, Jours d'entraînement")
    }

    @Test func notDueAndNextIntakeRowsAreFullSentences() {
        let thousand = SupplementText.number(1_000)
        let vitamin = supplement(dose: 1_000, unit: .iu)
        #expect(SupplementsModel.notDueRowSpoken(vitamin, days: "Jours d'entraînement")
            == "Vitamine D3, \(thousand) unités internationales, Jours d'entraînement")
        #expect(SupplementsModel.nextIntakeSpoken(item(vitamin))
            == "Prochaine prise, Vitamine D3, \(thousand) unités internationales, à 8 heures")
    }

    @Test func takenAnnouncementSaysTheCount() {
        let taken = item(supplement(dose: 1_000, unit: .iu), taken: true)
        #expect(SupplementsModel.takenAnnouncement(item: taken, taken: 3, due: 5) == "Vitamine D3 pris. 3 sur 5 pris.")
        let undone = item(supplement(dose: 1_000, unit: .iu), taken: false)
        #expect(SupplementsModel.takenAnnouncement(item: undone, taken: 2, due: 5) == "Vitamine D3, pas pris. 2 sur 5 pris.")
        #expect(SupplementsModel.takenAnnouncement(item: taken, taken: 5, due: 5)
            == "Vitamine D3 pris. 5 sur 5 pris. Tout est pris pour aujourd'hui.")
    }

    @Test func checkStateIsAToggleValue() {
        #expect(SupplementsModel.takenValue(true) == "Pris")
        #expect(SupplementsModel.takenValue(false) == "Pas pris")
    }

    @Test func rowLabelSaysTheStateAndTheDose() {
        let vitamin = item(supplement(dose: 1_000, unit: .iu), taken: true)
        let thousand = SupplementText.number(1_000)
        #expect(SupplementsModel.rowSpoken(vitamin) == "Vitamine D3, \(thousand) unités internationales, à 8 heures, pris")
        #expect(SupplementsModel.rowSpoken(item(supplement(dose: 5, unit: .gram)))
            == "Vitamine D3, 5 grammes, à 8 heures, pas pris")
    }

    @Test func unitsAreSpokenAsWords() {
        #expect(DoseUnit.allCases.map(SupplementLabels.unitSpoken)
            == ["grammes", "milligrammes", "microgrammes", "unités internationales", "millilitres", "doses"])
    }

    @Test func rateIsSpokenInPercent() {
        #expect(SupplementsModel.rateSpoken(SupplementRegularity(takenDays: 17, dueDays: 20)) == "85 pour cent")
        #expect(SupplementsModel.rateSpoken(nil) == "pas encore de jour prévu")
    }

    @Test func archiveAndSummary() {
        #expect(SupplementsModel.archivedAnnouncement("Whey") == "Whey archivé.")
        #expect(SupplementsModel.summarySpoken(taken: 2, due: 5) == "2 sur 5 pris")
    }
}

@MainActor
struct SupplementsAnnouncementTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private let now = DateComponents(calendar: Self.calendar, timeZone: Self.calendar.timeZone, year: 2026, month: 11, day: 20,
                                     hour: 9).date!
    private let repository = FailingIntakeRepository()
    private let model: SupplementsModel
    private let log = AnnouncementLog()

    init() {
        let now = now
        let service = SupplementService(supplements: repository, programs: InMemoryProgramRepository(),
                                        profiles: InMemoryProfileRepository(), workouts: InMemoryWorkoutRepository(),
                                        reminders: nil, health: nil, calendar: Self.calendar, now: { now })
        model = SupplementsModel(environment: SupplementsEnvironment(service: service,
                                                                     notifications: StubNotificationAuthorizer(granted: true),
                                                                     calendar: Self.calendar, now: { now }))
        let log = log
        model.announce = { text, isError in log.entries.append((text, isError)) }
    }

    private func save(_ name: String) async {
        var draft = SupplementDraft()
        draft.name = name
        draft.dose = 5
        draft.unit = .gram
        draft.reminder = false
        _ = await model.save(draft, editing: nil)
    }

    @Test func togglingAnnouncesTheNewCount() async throws {
        await save("Créatine")
        await save("Whey")
        let item = try #require(model.overview.items.first)
        await model.toggle(item)
        #expect(log.entries.map(\.text) == ["\(item.supplement.name) pris. 1 sur 2 pris."])
        await model.toggle(try #require(model.item(for: item.id)))
        #expect(log.entries.last?.text == "\(item.supplement.name), pas pris. 0 sur 2 pris.")
        #expect(log.entries.allSatisfy { !$0.isError })
    }

    @Test func archivingAnnouncesIt() async throws {
        await save("Créatine")
        await model.archive(try #require(model.overview.supplements.first))
        #expect(log.entries.map(\.text) == ["Créatine archivé."])
    }

    @Test func aFailedWriteIsAnnouncedAsAnErrorEachTime() async throws {
        await save("Créatine")
        let item = try #require(model.overview.items.first)
        await repository.setFailing(true)
        await model.toggle(item)
        await model.toggle(item)
        let errors = log.entries.filter(\.isError).map(\.text)
        #expect(errors == ["Pulse n'a pas pu enregistrer ta prise.", "Pulse n'a pas pu enregistrer ta prise."])
        #expect(log.entries.filter { !$0.isError }.isEmpty, "Une prise ratée ne dit pas « pris »")
    }
}

/// Un dépôt en mémoire dont les prises échouent sur demande.
actor FailingIntakeRepository: SupplementRepository {
    struct Failure: Error {}

    private let base = InMemorySupplementRepository()
    private var failing = false

    private var failingReads = false

    func setFailing(_ failing: Bool) { self.failing = failing }
    func setFailingReads(_ failing: Bool) { failingReads = failing }

    func supplements(includeArchived: Bool) async throws -> [Supplement] {
        if failingReads { throw Failure() }
        return try await base.supplements(includeArchived: includeArchived)
    }
    func save(_ supplement: Supplement) async throws { try await base.save(supplement) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }
    func intakes(from: Date, to: Date) async throws -> [SupplementIntake] { try await base.intakes(from: from, to: to) }
    func save(_ intake: SupplementIntake) async throws {
        if failing { throw Failure() }
        try await base.save(intake)
    }
    func delete(intakeID: UUID) async throws {
        if failing { throw Failure() }
        try await base.delete(intakeID: intakeID)
    }
}

@MainActor
extension SupplementsAnnouncementTests {
    @Test func aFailedReloadAfterAFailedToggleDoesNotAddASecondError() async throws {
        await save("Créatine")
        let item = try #require(model.overview.items.first)
        await repository.setFailing(true)
        await repository.setFailingReads(true)
        await model.toggle(item)
        #expect(log.entries.map(\.text) == ["Pulse n'a pas pu enregistrer ta prise."])
    }

    @Test func loadFailuresAreSilentUnlessAskedFor() async throws {
        await repository.setFailingReads(true)
        await model.load()
        #expect(log.entries.isEmpty, "La carte de l'accueil n'affiche pas d'erreur : elle reste muette")
        await model.load(announcesFailure: true)
        #expect(log.entries.map(\.text) == ["Pulse n'a pas pu lire tes compléments."])
        #expect(log.entries.allSatisfy { $0.isError })
    }
}

@MainActor
final class AnnouncementLog {
    var entries: [(text: String, isError: Bool)] = []
}
// swiftlint:enable force_unwrapping
