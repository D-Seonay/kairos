import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

/// Les textes de l'écran de séance, construits par des fonctions pures : colonnes, étiquettes VoiceOver, en-tête et repos.
@Suite struct LiveSessionTextTests {
    private func set(weight: Double? = nil, reps: Int? = nil, seconds: Int? = nil, type: SetType = .working) -> LiveSet {
        var set = LiveSet(proposed: ProposedSet(weightKg: weight, reps: reps, durationSeconds: seconds), previous: nil)
        set.setType = type
        return set
    }

    // MARK: Colonne de charge

    @Test func weightColumnFollowsTheLoadKind() {
        #expect(LiveSetRow.weightColumnTitle(for: .external) == "kg")
        #expect(LiveSetRow.weightColumnTitle(for: .bodyweight) == "+kg")
        #expect(LiveSetRow.weightColumnTitle(for: .assisted) == "\u{2212}kg")
    }

    @Test func weightIsWrittenTheFrenchWay() {
        #expect(LiveSetRow.weightText(62.5, loadKind: .external) == "62,5")
        #expect(LiveSetRow.weightText(70, loadKind: .external) == "70")
        #expect(LiveSetRow.weightText(nil, loadKind: .external) == "\u{2013}")
        #expect(LiveSetRow.weightText(nil, loadKind: .bodyweight) == "0")
        #expect(LiveSetRow.weightText(nil, loadKind: .assisted) == "0")
    }

    @Test func setBadgeShowsTheTypeLetter() {
        #expect(LiveSetRow.badge(for: .working, index: 2) == "3")
        #expect(LiveSetRow.badge(for: .warmup, index: 0) == "É")
        #expect(LiveSetRow.badge(for: .drop, index: 3) == "D")
        #expect(LiveSetRow.badge(for: .failure, index: 3) == "X")
    }

    // MARK: VoiceOver

    @Test func aProposedSetIsReadInFull() {
        let text = LiveSetRow.accessibilityText(for: set(weight: 70, reps: 5), index: 1, loadKind: .external)
        #expect(text == "Série 2, proposé 70 kilos, 5 répétitions, non validée")
    }

    @Test func anEditedSetDropsTheWordProposed() {
        var edited = set(weight: 70, reps: 5)
        edited.weightKg = 72.5
        edited.isEdited = true
        let text = LiveSetRow.accessibilityText(for: edited, index: 0, loadKind: .external)
        #expect(text == "Série 1, 72,5 kilos, 5 répétitions, non validée")
    }

    @Test func aValidatedSetSaysItsRPE() {
        var done = set(weight: 70, reps: 5)
        done.rpe = 8.5
        done.completedAt = LiveClock.date("2026-11-02T08:30")
        let text = LiveSetRow.accessibilityText(for: done, index: 2, loadKind: .external)
        #expect(text == "Série 3, 70 kilos, 5 répétitions, RPE 8,5, validée")
    }

    @Test func singularsAndTypes() {
        let text = LiveSetRow.accessibilityText(for: set(weight: 1, reps: 1, type: .warmup), index: 0, loadKind: .external)
        #expect(text == "Série 1, échauffement, proposé 1 kilo, 1 répétition, non validée")
        let drop = LiveSetRow.accessibilityText(for: set(weight: 15, reps: 10, type: .drop), index: 3, loadKind: .external)
        #expect(drop == "Série 4, dégressive, proposé 15 kilos, 10 répétitions, non validée")
        let failure = LiveSetRow.accessibilityText(for: set(weight: 15, reps: 10, type: .failure), index: 3, loadKind: .external)
        #expect(failure == "Série 4, à l'échec, proposé 15 kilos, 10 répétitions, non validée")
    }

    @Test func bodyweightAndAssistedLoadsAreNamed() {
        let weighted = LiveSetRow.accessibilityText(for: set(weight: 10, reps: 8), index: 0, loadKind: .bodyweight)
        #expect(weighted == "Série 1, proposé lest de 10 kilos, 8 répétitions, non validée")
        let bare = LiveSetRow.accessibilityText(for: set(weight: 0, reps: 12), index: 0, loadKind: .bodyweight)
        #expect(bare == "Série 1, proposé 12 répétitions, non validée")
        let assisted = LiveSetRow.accessibilityText(for: set(weight: 20, reps: 6), index: 0, loadKind: .assisted)
        #expect(assisted == "Série 1, proposé assistance de 20 kilos, 6 répétitions, non validée")
    }

    @Test func durationsAreReadInSeconds() {
        let text = LiveSetRow.accessibilityText(for: set(seconds: 30), index: 0, loadKind: .bodyweight, tracksDuration: true)
        #expect(text == "Série 1, proposé 30 secondes, non validée")
        let single = LiveSetRow.accessibilityText(for: set(seconds: 1), index: 0, loadKind: .bodyweight, tracksDuration: true)
        #expect(single == "Série 1, proposé 1 seconde, non validée")
    }

    @Test func missingValuesAreAskedFor() {
        let text = LiveSetRow.accessibilityText(for: set(), index: 0, loadKind: .external)
        #expect(text == "Série 1, charge à saisir, répétitions à saisir, non validée")
    }

    // MARK: En-tête

    @Test func headerShowsTheProgressAndTheTonnage() {
        #expect(LiveHeader.progressText(done: 4, planned: 14) == "4 / 14")
        #expect(LiveHeader.progressAccessibilityText(done: 4, planned: 14) == "4 séries faites sur 14")
        #expect(LiveHeader.progressAccessibilityText(done: 1, planned: 1) == "1 série faite sur 1")
        #expect(LiveHeader.tonnageText(kg: 1_240) == "1240 kg")
        #expect(LiveHeader.tonnageText(kg: 62.5) == "62,5 kg")
        #expect(LiveHeader.tonnageText(kg: 0) == "0 kg")
    }

    // MARK: Carte d'exercice

    @Test func exerciseCardTexts() {
        #expect(LiveExerciseCard.rpeCapText(7.5) == "RPE 7,5 max")
        #expect(LiveExerciseCard.rpeCapText(8) == "RPE 8 max")
        #expect(LiveExerciseCard.supersetText(group: 1) == "Super set A")
        #expect(LiveExerciseCard.supersetText(group: 2) == "Super set B")
        #expect(LiveExerciseCard.incrementText(2.5) == "2,5 kg")
        #expect(LiveExerciseCard.incrementText(5) == "5 kg")
    }

    // MARK: Repos

    private func session() -> LiveSession {
        let bench = LiveExercise(
            exercise: .content(id: "bench-press-barbell"), name: "Développé couché", loadKind: .external, tracksDuration: false,
            isBarbell: true,
            incrementKg: 2.5, restSeconds: 120,
            sets: [LiveSet(proposed: ProposedSet(weightKg: 70, reps: 5), previous: nil),
                   LiveSet(proposed: ProposedSet(weightKg: 72.5, reps: 5), previous: nil)])
        let plank = LiveExercise(
            exercise: .content(id: "plank"), name: "Gainage", loadKind: .bodyweight, tracksDuration: true, isBarbell: false,
            incrementKg: 2.5, restSeconds: 60, sets: [LiveSet(proposed: ProposedSet(durationSeconds: 45), previous: nil)])
        return LiveSession(title: "Push", startedAt: LiveClock.date("2026-11-02T08:00"),
                           lastActionAt: LiveClock.date("2026-11-02T08:00"), exercises: [bench, plank])
    }

    @Test func nextSetNamesTheExerciseTheSetAndItsValues() {
        var live = session()
        live.exercises[0].sets[0].completedAt = LiveClock.date("2026-11-02T08:10")
        #expect(RestBanner.nextSetText(in: live) == "Développé couché, série 2 : 72,5 kg × 5")
        live.exercises[0].sets[1].completedAt = LiveClock.date("2026-11-02T08:15")
        #expect(RestBanner.nextSetText(in: live) == "Gainage, série 1 : 45 s")
        live.exercises[1].sets[0].completedAt = LiveClock.date("2026-11-02T08:20")
        #expect(RestBanner.nextSetText(in: live) == nil)
    }

    @Test func plannedTextCoversEveryLoadKind() {
        let bodyweight = set(weight: 10, reps: 8)
        #expect(LiveSetRow.plannedText(bodyweight, loadKind: .bodyweight, tracksDuration: false) == "+10 kg × 8")
        let assisted = set(weight: 20, reps: 6)
        #expect(LiveSetRow.plannedText(assisted, loadKind: .assisted, tracksDuration: false) == "\u{2212}20 kg × 6")
        #expect(LiveSetRow.plannedText(set(reps: 12), loadKind: .bodyweight, tracksDuration: false) == "12 rép.")
        #expect(LiveSetRow.plannedText(set(), loadKind: .external, tracksDuration: false) == nil)
    }

    @Test func restRingEmptiesWithTheTime() {
        let start = LiveClock.date("2026-11-02T08:10")
        let rest = LiveRest(startedAt: start, endsAt: start.addingTimeInterval(120), exerciseID: UUID())
        #expect(RestBanner.remainingFraction(of: rest, at: start) == 1)
        #expect(RestBanner.remainingFraction(of: rest, at: start.addingTimeInterval(30)) == 0.75)
        #expect(RestBanner.remainingFraction(of: rest, at: start.addingTimeInterval(500)) == 0)
        #expect(RestBanner.remainingFraction(of: rest, at: start.addingTimeInterval(-10)) == 1)
    }

    @Test func restPlus30StillHasAFractionBelowOne() {
        // +30 s repousse la fin sans toucher au début : l'anneau garde la durée de départ comme référence.
        let start = LiveClock.date("2026-11-02T08:10")
        let rest = LiveRest(startedAt: start, endsAt: start.addingTimeInterval(150), exerciseID: UUID())
        #expect(RestBanner.remainingFraction(of: rest, at: start.addingTimeInterval(75)) == 0.5)
    }

    // MARK: Valeurs proposées, clavier, RPE

    @Test func onlyTheChangedValueLosesTheAccent() {
        var edited = set(weight: 70, reps: 5)
        #expect(LiveSetRow.isProposed(.weight, in: edited))
        edited.weightKg = 72.5
        edited.isEdited = true
        #expect(!LiveSetRow.isProposed(.weight, in: edited))
        #expect(LiveSetRow.isProposed(.reps, in: edited))
    }

    @Test func keypadTitleAndStepsFollowTheField() {
        #expect(NumericKeypad.title(exercise: "Dips", setIndex: 1, field: .weight, loadKind: .bodyweight) == "Dips · Série 2 · +kg")
        #expect(NumericKeypad.title(exercise: "Dips", setIndex: 0, field: .reps, loadKind: .bodyweight) == "Dips · Série 1 · Répétitions")
        #expect(NumericKeypad.stepText(for: .weight, increment: 2.5, sign: 1) == "+2,5")
        #expect(NumericKeypad.stepText(for: .reps, increment: 2.5, sign: -1) == "\u{2212}1")
        #expect(NumericKeypad.stepText(for: .duration, increment: 2.5, sign: 1) == "+5")
        #expect(NumericKeypad.stepSpokenText(for: .weight, increment: 2.5, sign: -1) == "Retirer 2,5")
        #expect(NumericKeypad.identifier(for: .digit(7)) == "live.key.7")
        #expect(NumericKeypad.identifier(for: .next) == "live.key.next")
    }

    @Test func rpePillsGoFromSixToTenByHalves() {
        #expect(RPEPicker.values.count == 9)
        #expect(RPEPicker.values.first == 6)
        #expect(RPEPicker.values.last == 10)
        #expect(RPEPicker.label(for: 7.5) == "7,5")
        #expect(RPEPicker.label(for: 8) == "8")
        #expect(RPEPicker.title(exercise: "Squat", setIndex: 2) == "Squat · Série 3 · RPE")
    }

    @Test func identifiersFollowTheBrief() {
        #expect(LiveSessionIdentifiers.check(exercise: 0, set: 1) == "live.exercise.0.set.1.check")
        #expect(LiveSessionIdentifiers.weight(exercise: 2, set: 0) == "live.exercise.2.set.0.weight")
        #expect(LiveSessionIdentifiers.restSkip == "live.rest.skip")
        #expect(LiveSessionIdentifiers.menuButton == "live.menu")
        #expect(LiveSessionIdentifiers.abandonButton == "live.abandon")
        #expect(LiveSessionIdentifiers.finishButton == "live.finish")
    }

    @Test func untitledSessionsAreCalledSeance() {
        #expect(LiveHeader.titleText("") == "Séance")
        #expect(LiveHeader.titleText("Push") == "Push")
    }
}
