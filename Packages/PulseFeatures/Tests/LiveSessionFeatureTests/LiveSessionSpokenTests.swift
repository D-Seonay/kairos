import Foundation
@testable import LiveSessionFeature
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import SwiftUI
import Testing

/// Ce que VoiceOver dit de la séance en direct : cellules, clavier, repos, en-tête, calculateur de disques. Des fonctions pures.
@Suite struct LiveSessionSpokenTests {
    private func session() -> LiveSession {
        let bench = LiveExercise(
            exercise: .content(id: "bench-press-barbell"), name: "Développé couché", loadKind: .external, tracksDuration: false,
            isBarbell: true, incrementKg: 2.5, restSeconds: 120,
            sets: [LiveSet(proposed: ProposedSet(weightKg: 70, reps: 5), previous: nil),
                   LiveSet(proposed: ProposedSet(weightKg: 72.5, reps: 5), previous: nil)])
        let plank = LiveExercise(
            exercise: .content(id: "plank"), name: "Gainage", loadKind: .bodyweight, tracksDuration: true, isBarbell: false,
            incrementKg: 2.5, restSeconds: 60, sets: [LiveSet(proposed: ProposedSet(durationSeconds: 45), previous: nil)])
        return LiveSession(title: "Push", startedAt: LiveClock.date("2026-11-02T08:00"),
                           lastActionAt: LiveClock.date("2026-11-02T08:00"), exercises: [bench, plank])
    }

    // MARK: Cellules d'une série

    @Test func weightCellsSayWhatTheyHoldInKilos() {
        #expect(LiveSetRow.weightSpokenTitle(for: .external) == "Charge en kilos")
        #expect(LiveSetRow.weightSpokenTitle(for: .bodyweight) == "Lest en kilos")
        #expect(LiveSetRow.weightSpokenTitle(for: .assisted) == "Assistance en kilos")
    }

    @Test func cellValueSaysProposedOrEmpty() {
        #expect(LiveSetRow.cellSpokenValue(text: "62,5", isEmpty: false, isProposed: true) == "62,5, proposé")
        #expect(LiveSetRow.cellSpokenValue(text: "62,5", isEmpty: false, isProposed: false) == "62,5")
        #expect(LiveSetRow.cellSpokenValue(text: "\u{2013}", isEmpty: true, isProposed: true) == "vide")
    }

    @Test func visibleCellTitlesNameTheValue() {
        #expect(LiveSetRow.cellTitle(for: .weight, loadKind: .external) == "Charge (kg)")
        #expect(LiveSetRow.cellTitle(for: .weight, loadKind: .bodyweight) == "Lest (kg)")
        #expect(LiveSetRow.cellTitle(for: .weight, loadKind: .assisted) == "Assistance (kg)")
        #expect(LiveSetRow.cellTitle(for: .reps, loadKind: .external) == "Reps")
        #expect(LiveSetRow.cellTitle(for: .duration, loadKind: .external) == "Sec")
    }

    @Test func checkSaysTheSetAndItsState() {
        #expect(LiveSetRow.checkSpokenLabel(index: 1, type: .working) == "Série 2")
        #expect(LiveSetRow.checkSpokenLabel(index: 0, type: .warmup) == "Série 1, échauffement")
        #expect(LiveSetRow.checkSpokenValue(isDone: true) == "validée")
        #expect(LiveSetRow.checkSpokenValue(isDone: false) == "non validée")
    }

    @Test func rowsStackFromTheLargerTextSizes() {
        #expect(!LiveSetRow.usesStackedLayout(.large))
        #expect(!LiveSetRow.usesStackedLayout(.xLarge))
        #expect(LiveSetRow.usesStackedLayout(.xxLarge))
        #expect(LiveSetRow.usesStackedLayout(.accessibility3))
    }

    @Test func plannedValuesAreSpokenWithUnits() {
        let set = LiveSet(proposed: ProposedSet(weightKg: 70, reps: 5), previous: nil)
        #expect(LiveSetRow.plannedSpokenText(for: set, loadKind: .external, tracksDuration: false) == "70 kilos, 5 répétitions")
        let hold = LiveSet(proposed: ProposedSet(durationSeconds: 45), previous: nil)
        #expect(LiveSetRow.plannedSpokenText(for: hold, loadKind: .bodyweight, tracksDuration: true) == "45 secondes")
        let empty = LiveSet(proposed: ProposedSet(), previous: nil)
        #expect(LiveSetRow.plannedSpokenText(for: empty, loadKind: .external, tracksDuration: false) == nil)
    }

    @Test func addButtonsNameTheirTarget() {
        #expect(LiveExerciseCard.addSetSpokenText(exercise: "Développé couché") == "Ajouter une série à Développé couché")
        #expect(LiveSessionView.addExerciseSpokenText == "Ajouter un exercice")
    }

    // MARK: Clavier

    @Test func keypadStepsSayTheirUnit() {
        #expect(NumericKeypad.stepSpokenText(for: .weight, increment: 2.5, sign: -1) == "Retirer 2,5 kilos")
        #expect(NumericKeypad.stepSpokenText(for: .weight, increment: 1, sign: 1) == "Ajouter 1 kilo")
        #expect(NumericKeypad.stepSpokenText(for: .reps, increment: 2.5, sign: 1) == "Ajouter 1 répétition")
        #expect(NumericKeypad.stepSpokenText(for: .duration, increment: 2.5, sign: -1) == "Retirer 5 secondes")
    }

    @Test func keypadValueIsSpokenWithItsUnit() {
        #expect(NumericKeypad.valueAnnouncement(field: .weight, text: "62,5") == "62,5 kilos")
        #expect(NumericKeypad.valueAnnouncement(field: .weight, text: "1") == "1 kilo")
        #expect(NumericKeypad.valueAnnouncement(field: .weight, text: "62,") == "62 virgule")
        #expect(NumericKeypad.valueAnnouncement(field: .reps, text: "8") == "8 répétitions")
        #expect(NumericKeypad.valueAnnouncement(field: .reps, text: "1") == "1 répétition")
        #expect(NumericKeypad.valueAnnouncement(field: .duration, text: "45") == "45 secondes")
        #expect(NumericKeypad.valueAnnouncement(field: .reps, text: "") == "vide")
    }

    @Test func keypadAnnouncesOnlyAChangedValue() {
        #expect(NumericKeypad.keypadAnnouncement(key: .digit(2), before: "6", after: "62", field: .weight) == "62 kilos")
        #expect(NumericKeypad.keypadAnnouncement(key: .delete, before: "62", after: "6", field: .weight) == "6 kilos")
        #expect(NumericKeypad.keypadAnnouncement(key: .delete, before: "", after: "", field: .reps) == nil)
        #expect(NumericKeypad.keypadAnnouncement(key: .next, before: "6", after: "8", field: .reps) == nil)
    }

    @Test func keypadTitleIsSpokenWithoutSymbols() {
        #expect(NumericKeypad.spokenTitle(exercise: "Développé couché", setIndex: 1, field: .weight, loadKind: .external)
                == "Développé couché, série 2, charge en kilos")
        #expect(NumericKeypad.spokenTitle(exercise: "Dips", setIndex: 0, field: .weight, loadKind: .bodyweight)
                == "Dips, série 1, lest en kilos")
        #expect(NumericKeypad.spokenTitle(exercise: "Dips", setIndex: 0, field: .reps, loadKind: .bodyweight)
                == "Dips, série 1, répétitions")
        #expect(NumericKeypad.spokenTitle(exercise: "Gainage", setIndex: 2, field: .duration, loadKind: .bodyweight)
                == "Gainage, série 3, secondes")
        #expect(RPEPicker.spokenTitle(exercise: "Squat", setIndex: 2) == "Squat, série 3, RPE")
    }

    // MARK: Repos

    @Test func restStartAndEndAreSpoken() {
        #expect(RestBanner.restStartedText(seconds: 90) == "Repos de 1 minute 30")
        #expect(RestBanner.restStartedText(seconds: 165) == "Repos de 2 minutes 45")
        #expect(RestBanner.restEndedText(next: "Développé couché, série 3 : 70 kilos, 5 répétitions")
                == "Repos terminé. Série suivante : Développé couché, série 3 : 70 kilos, 5 répétitions")
        #expect(RestBanner.restEndedText(next: nil) == "Repos terminé")
        #expect(RestBanner.restSkippedText(next: "Gainage, série 1 : 45 secondes")
                == "Repos passé. Série suivante : Gainage, série 1 : 45 secondes")
        #expect(RestBanner.restSkippedText(next: nil) == "Repos passé")
    }

    @Test func remainingRestIsSpokenInWords() {
        let start = LiveClock.date("2026-11-02T08:10")
        let rest = LiveRest(startedAt: start, endsAt: start.addingTimeInterval(120), exerciseID: UUID())
        #expect(RestBanner.remainingSpokenText(of: rest, at: start.addingTimeInterval(30)) == "1 minute 30")
        #expect(RestBanner.remainingSpokenText(of: rest, at: start.addingTimeInterval(74.4)) == "46 secondes")
        #expect(RestBanner.remainingSpokenText(of: rest, at: start.addingTimeInterval(500)) == "0 seconde")
    }

    @Test func nextSetIsSpokenWithUnits() {
        var live = session()
        live.exercises[0].sets[0].completedAt = LiveClock.date("2026-11-02T08:10")
        #expect(RestBanner.nextSetSpokenText(in: live) == "Développé couché, série 2 : 72,5 kilos, 5 répétitions")
        live.exercises[0].sets[1].completedAt = LiveClock.date("2026-11-02T08:15")
        #expect(RestBanner.nextSetSpokenText(in: live) == "Gainage, série 1 : 45 secondes")
        live.exercises[1].sets[0].completedAt = LiveClock.date("2026-11-02T08:20")
        #expect(RestBanner.nextSetSpokenText(in: live) == nil)
    }

    @Test func restIsAnnouncedOnceWhenItStartsAndOnceWhenItEnds() {
        var live = session()
        let start = LiveClock.date("2026-11-02T08:10")
        live.exercises[0].sets[0].completedAt = start
        var rest = LiveRest(startedAt: start, endsAt: start.addingTimeInterval(120), exerciseID: live.exercises[0].id)
        live.rest = rest
        var announced: [RestBanner.Announcement] = []
        // Ce que `pulseAnnounceOnce` fait de la suite des annonces : un identifiant déjà dit ne se redit pas.
        func see(_ announcement: RestBanner.Announcement?) {
            guard let announcement, !announced.contains(where: { $0.event == announcement.event }) else { return }
            announced.append(announcement)
        }

        #expect(RestBanner.announcement(for: nil, endReached: nil, in: live) == nil)
        see(RestBanner.announcement(for: rest, endReached: nil, in: live))
        rest.endsAt = rest.endsAt.addingTimeInterval(30)  // +30 s : même repos, rien de neuf à dire.
        live.rest = rest
        see(RestBanner.announcement(for: rest, endReached: nil, in: live))
        see(RestBanner.announcement(for: rest, endReached: start, in: live))
        see(RestBanner.announcement(for: rest, endReached: start, in: live))

        #expect(announced.map(\.text) == [
            "Repos de 2 minutes",
            "Repos terminé. Série suivante : Développé couché, série 2 : 72,5 kilos, 5 répétitions"
        ])
        // Le repos suivant a son propre identifiant : il est annoncé à son tour.
        let next = LiveRest(startedAt: start.addingTimeInterval(300), endsAt: start.addingTimeInterval(360),
                            exerciseID: live.exercises[0].id)
        see(RestBanner.announcement(for: next, endReached: start, in: live))
        #expect(announced.count == 3)
        #expect(announced.last?.text == "Repos de 1 minute")
    }

    // MARK: En-tête

    @Test func headerStatsAreSpokenWithUnits() {
        #expect(LiveHeader.tonnageSpokenText(kg: 1_240) == "1\u{202F}240 kilos")
        #expect(LiveHeader.tonnageSpokenText(kg: 62.5) == "62,5 kilos")
        #expect(LiveHeader.durationSpokenText(minutes: 65) == "1 heure 5 minutes")
        #expect(LiveHeader.durationSpokenText(minutes: 55) == "55 minutes")
        let start = LiveClock.date("2026-11-02T08:00")
        #expect(LiveHeader.elapsedSpokenText(from: start, to: start.addingTimeInterval(12 * 60 + 3)) == "12 minutes")
        #expect(LiveHeader.elapsedSpokenText(from: start, to: start.addingTimeInterval(20)) == "Moins d'une minute")
    }

    // MARK: Calculateur de disques

    @Test func platesPerSideAreSpokenInKilos() {
        #expect(PlateCalculatorSheet.perSideSpokenText(PlateLoading(totalKg: 70, perSide: [25])) == "Par côté : 25 kilos")
        #expect(PlateCalculatorSheet.perSideSpokenText(PlateLoading(totalKg: 70, perSide: [20, 5]))
                == "Par côté : 20 kilos et 5 kilos")
        #expect(PlateCalculatorSheet.perSideSpokenText(PlateLoading(totalKg: 102.5, perSide: [25, 15, 1.25]))
                == "Par côté : 25 kilos, 15 kilos et 1,25 kilo")
        #expect(PlateCalculatorSheet.perSideSpokenText(PlateLoading(totalKg: 20, perSide: [])) == "Barre seule")
    }

    @Test func plateChoicesAndLoadAreSpoken() {
        #expect(PlateCalculatorSheet.choiceSpokenText(PlateLoading(totalKg: 90, perSide: [25, 10]))
                == "Appliquer 90 kilos, par côté 25 kilos et 10 kilos")
        #expect(PlateCalculatorSheet.choiceSpokenText(PlateLoading(totalKg: 20, perSide: [])) == "Appliquer 20 kilos, barre seule")
        #expect(PlateCalculatorSheet.loadSpokenText(62.5) == "Charge 62,5 kilos")
        #expect(PlateCalculatorSheet.loadAnnouncement(load: 70, result: .exact(PlateLoading(totalKg: 70, perSide: [20, 5])))
                == "70 kilos. Par côté : 20 kilos et 5 kilos")
        #expect(PlateCalculatorSheet.loadAnnouncement(load: 71, result: .approximate(lower: nil, upper: nil))
                == "71 kilos. Impossible tout juste avec tes disques")
        #expect(PlateCalculatorSheet.plateSpokenText(2.5) == "2,5 kilos")
    }

    // MARK: Remplacement

    @Test func replacementProposalIsSpokenWithoutSymbols() {
        let replacement = LiveExercise(
            exercise: .content(id: "dumbbell-bench-press"), name: "Développé haltères", loadKind: .external,
            tracksDuration: false, isBarbell: false, incrementKg: 2, restSeconds: 120,
            sets: [LiveSet(proposed: ProposedSet(weightKg: 24, reps: 10), previous: nil),
                   LiveSet(proposed: ProposedSet(weightKg: 24, reps: 10), previous: nil)])
        #expect(ReplaceExerciseSheet.proposalSpokenText(replacement)
                == "2 séries, 24 kilos, 10 répétitions, charge estimée")
        #expect(ReplaceExerciseSheet.optionSpokenLabel(name: "Développé haltères", replacement: replacement)
                == "Développé haltères, 2 séries, 24 kilos, 10 répétitions, charge estimée")
        #expect(ReplaceExerciseSheet.loadingSpokenText == "Chargement des alternatives")
    }
}
