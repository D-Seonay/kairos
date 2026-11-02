import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct ExerciseBrowserTests {
    private let all = ExerciseDirectory(library: .bundled, userExercises: []).active

    @Test func searchIgnoresAccentsAndPutsRecentsFirst() {
        let found = ExerciseBrowser.results(all, query: "developpe couche", group: nil, equipment: nil,
                                            recent: [.content(id: "bench-press-dumbbell")])
        #expect(found.first?.reference == .content(id: "bench-press-dumbbell"))
        #expect(found.contains { $0.reference == .content(id: "bench-press-barbell") })
        let filtered = ExerciseBrowser.results(all, query: "", group: .arms, equipment: .cable, recent: [])
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.group == .arms && $0.equipment == .cable })
    }

    @Test func everyQueryWordMustAppear() {
        let found = ExerciseBrowser.results(all, query: "COUCHÉ haltères", group: nil, equipment: nil, recent: [])
        #expect(!found.isEmpty)
        #expect(found.allSatisfy { SearchText.fold($0.name).contains("couche") })
        #expect(ExerciseBrowser.results(all, query: "couche zzzz", group: nil, equipment: nil, recent: []).isEmpty)
    }

    @Test func searchAlsoMatchesTheEnglishName() throws {
        let english = try #require(all.compactMap(\.englishName).first)
        let found = ExerciseBrowser.results(all, query: english, group: nil, equipment: nil, recent: [])
        #expect(found.contains { $0.englishName == english })
    }

    @Test func nonRecentsAreSortedAlphabeticallyInFrench() {
        let found = ExerciseBrowser.results(all, query: "", group: nil, equipment: nil, recent: [])
        let names = found.map(\.name)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(found.count == all.count)
    }

    @Test func recentsFollowTheirOwnOrderAndIgnoreUnmatchedOnes() {
        let recent: [ExerciseReference] = [.content(id: "triceps-pushdown-cable"), .content(id: "pec-deck-machine"), .user(id: UUID())]
        let found = ExerciseBrowser.results(all, query: "", group: nil, equipment: nil, recent: recent)
        #expect(found.prefix(2).map(\.reference) == Array(recent.prefix(2)))
        #expect(found.count == all.count)
        let narrowed = ExerciseBrowser.results(all, query: "", group: .chest, equipment: nil, recent: recent)
        #expect(narrowed.first?.reference == .content(id: "pec-deck-machine"))
        #expect(!narrowed.contains { $0.reference == .content(id: "triceps-pushdown-cable") })
    }
}
