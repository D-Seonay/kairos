// swiftlint:disable force_unwrapping
import Foundation
import PulseDomain
import PulseServices
@testable import SupplementsFeature
import Testing

@MainActor
struct SupplementsModelTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private let now = DateComponents(calendar: Self.calendar, timeZone: Self.calendar.timeZone, year: 2026, month: 11, day: 20,
                                     hour: 9).date!
    private let repository = InMemorySupplementRepository()
    private let notifications = StubNotificationAuthorizer(granted: true)
    private let health = StubSupplementHealthWriter(access: .notDetermined)
    private let model: SupplementsModel

    init() {
        let now = now
        let service = SupplementService(supplements: repository, programs: InMemoryProgramRepository(),
                                        profiles: InMemoryProfileRepository(), workouts: InMemoryWorkoutRepository(),
                                        reminders: nil, health: health, calendar: Self.calendar, now: { now })
        model = SupplementsModel(environment: SupplementsEnvironment(service: service, notifications: notifications,
                                                                     calendar: Self.calendar, now: { now }))
    }

    private func draft(_ name: String, dose: Double? = 5, reminder: Bool = true,
                       health: SupplementHealthType? = nil) -> SupplementDraft {
        var draft = SupplementDraft()
        draft.name = name
        draft.dose = dose
        draft.unit = .gram
        draft.minutes = 20 * 60
        draft.reminder = reminder
        draft.healthType = health
        return draft
    }

    @Test func savingANewSupplementAsksForNotificationsAndHealthOnce() async throws {
        model.startNew()
        #expect(await model.save(draft("Whey", health: .protein), editing: nil))
        #expect(model.editor == nil)
        #expect(await notifications.requestCount == 1)
        #expect(await health.requestCount == 1)
        #expect(model.overview.items.map(\.supplement.name) == ["Whey"])

        #expect(await model.save(draft("Créatine", reminder: false), editing: nil))
        #expect(await notifications.requestCount == 1)
        #expect(await health.requestCount == 1)
        #expect(model.overview.supplements.map(\.order) == [0, 1])
    }

    @Test func anIncompleteDraftIsNotSaved() async throws {
        #expect(await !model.save(draft("  "), editing: nil))
        #expect(await !model.save(draft("Zinc", dose: nil), editing: nil))
        #expect(try await repository.supplements(includeArchived: true).isEmpty)
    }

    @Test func toggleTakesThenUntakes() async throws {
        _ = await model.save(draft("Créatine"), editing: nil)
        let item = try #require(model.overview.items.first)
        await model.toggle(item)
        #expect(model.overview.takenCount == 1)
        #expect(model.countText == "1 sur 1")
        await model.toggle(try #require(model.item(for: item.id)))
        #expect(model.overview.takenCount == 0)
    }

    @Test func editingKeepsIdentityAndArchiveHidesIt() async throws {
        _ = await model.save(draft("Créatine"), editing: nil)
        let saved = try #require(model.overview.supplements.first)
        var changed = SupplementDraft(saved)
        changed.name = "Créatine monohydrate"
        #expect(await model.save(changed, editing: saved))
        #expect(model.overview.supplements.map(\.id) == [saved.id])
        #expect(model.overview.supplements.first?.name == "Créatine monohydrate")

        await model.archive(try #require(model.overview.supplements.first))
        #expect(model.overview.supplements.isEmpty)
        #expect(try await repository.supplements(includeArchived: true).first?.isArchived == true)
    }

    @Test func unarchiveBringsTheSupplementBackAndSaysIt() async throws {
        var spoken: [String] = []
        model.announce = { text, _ in spoken.append(text) }
        _ = await model.save(draft("Zinc"), editing: nil)
        await model.archive(try #require(model.overview.supplements.first))
        let archived = try #require(model.overview.archived.first)
        #expect(archived.name == "Zinc" && model.overview.supplements.isEmpty)

        await model.unarchive(archived)
        #expect(model.overview.archived.isEmpty)
        #expect(model.overview.supplements.map(\.id) == [archived.id])
        #expect(model.overview.items.map(\.supplement.name) == ["Zinc"])
        #expect(spoken.last == "Zinc de retour dans tes compléments.")
        #expect(model.errorMessage == nil)
    }
}

struct SupplementDraftTests {
    @Test func suggestionsFillEverythingButTheDose() throws {
        var draft = SupplementDraft()
        draft.dose = 2
        let vitamin = try #require(SupplementCatalog.suggestions.first { $0.id == "vitamin-d" })
        draft.apply(vitamin)
        #expect(draft.unit == .iu && draft.healthType == .vitaminD && draft.timing == .fixedTime)
        #expect(draft.dose == 2)
        #expect(SupplementCatalog.suggestions.allSatisfy { suggestion in
            var fresh = SupplementDraft()
            fresh.apply(suggestion)
            return fresh.dose == nil
        })
    }

    @Test func problemsAndHealthNote() {
        var draft = SupplementDraft()
        #expect(draft.problem != nil)
        draft.name = "Vitamine D3"
        draft.dose = 1_000
        draft.unit = .iu
        #expect(draft.problem == nil)
        draft.days = .custom
        #expect(draft.problem != nil)
        draft.weekdays = [.monday]
        #expect(draft.problem == nil)

        #expect(draft.healthNote == nil)
        draft.healthType = .vitaminD
        #expect(draft.healthNote?.contains("25") == true)
        draft.unit = .ml
        #expect(draft.healthNote?.contains("cette unité") == true)
    }

    @Test func savedSupplementDropsFieldsThatDoNotApply() {
        var draft = SupplementDraft()
        draft.name = " Whey "
        draft.dose = 30
        draft.setTiming(.afterWorkout)
        draft.weekdays = [.friday]
        draft.threshold = 5
        let now = Date(timeIntervalSince1970: 0)
        let supplement = draft.supplement(existing: nil, order: 3, now: now)
        #expect(supplement.name == "Whey" && supplement.order == 3)
        #expect(supplement.timeOfDayMinutes == nil && supplement.customWeekdays.isEmpty)
        #expect(supplement.lowStockThreshold == nil)
    }

    @Test func switchingToBedtimeMovesTheTime() {
        var draft = SupplementDraft()
        draft.setTiming(.bedtime)
        #expect(draft.minutes == 22 * 60 + 30)
        draft.setTiming(.fixedTime)
        #expect(draft.minutes == 8 * 60)
    }

    @Test func followingNightsIsProposedForBedtimeAndHidesTheTimeOnlyWithAHabitualTime() {
        var draft = SupplementDraft()
        #expect(!draft.savesFollowingNights)
        draft.setTiming(.bedtime)
        #expect(draft.savesFollowingNights)
        #expect(!draft.showsTimePicker(habitualBedtime: 23 * 60))
        #expect(draft.showsTimePicker(habitualBedtime: nil))
        draft.followsNights = false
        #expect(draft.showsTimePicker(habitualBedtime: 23 * 60))

        var supplement = draft.supplement(existing: nil, order: 0, now: .now)
        #expect(!SupplementDraft(supplement).followsNights)
        #expect(SupplementDraft(supplement, followsNights: true).followsNights)
        supplement.timing = .fixedTime
        #expect(!SupplementDraft(supplement, followsNights: true).followsNights)
    }
}
// swiftlint:enable force_unwrapping
