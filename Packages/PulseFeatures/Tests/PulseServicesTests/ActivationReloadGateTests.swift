import Foundation
@testable import PulseServices
import Testing

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
    return calendar
}()

/// 27 novembre 2026, à `hour`:`minute` à Paris.
private func at(_ hour: Int, _ minute: Int, day: Int = 27) -> Date {
    paris.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)) ?? .distantPast
}

/// Relit si la porte le dit, et note la fin de la relecture.
private func activate(_ gate: inout ActivationReloadGate, at date: Date) -> Bool {
    guard gate.beginReload(at: date, calendar: paris) else { return false }
    gate.endReload(at: date)
    return true
}

@Test func theFirstActivationReloads() {
    var gate = ActivationReloadGate()
    #expect((activate(&gate, at: at(9, 0)) as Bool))
}

@Test func twoCloseActivationsReloadOnce() {
    var gate = ActivationReloadGate()
    #expect((activate(&gate, at: at(9, 0)) as Bool))
    #expect(!(activate(&gate, at: at(9, 2)) as Bool))
    #expect(!(activate(&gate, at: at(9, 9)) as Bool))
}

@Test func anOldReloadIsRedone() {
    var gate = ActivationReloadGate(maxAge: 10 * 60)
    #expect((activate(&gate, at: at(9, 0)) as Bool))
    #expect((activate(&gate, at: at(9, 10)) as Bool))
}

@Test func midnightStillReloads() {
    var gate = ActivationReloadGate()
    #expect((activate(&gate, at: at(23, 58)) as Bool))
    #expect((activate(&gate, at: at(0, 1, day: 28)) as Bool))
}

@Test func aNotedChangeReloadsAtTheNextActivation() {
    var gate = ActivationReloadGate()
    #expect((activate(&gate, at: at(9, 0)) as Bool))
    gate.noteSave()
    #expect((activate(&gate, at: at(9, 1)) as Bool))
    #expect(!(activate(&gate, at: at(9, 2)) as Bool))
}

/// Les écritures faites par la relecture elle-même ne relancent pas une relecture au retour suivant.
@Test func changesDuringTheReloadAreItsOwn() {
    var gate = ActivationReloadGate()
    let started = gate.beginReload(at: at(9, 0), calendar: paris)
    #expect(started)
    gate.noteSave()
    gate.endReload(at: at(9, 0))
    #expect(!(activate(&gate, at: at(9, 1)) as Bool))
}

/// Un import iCloud (le check-in fait sur l'iPad) arrive pendant la relecture, après qu'elle a lu l'accueil : le retour suivant
/// relit, une seule fois.
@Test func anExternalChangeDuringTheReloadIsKept() {
    var gate = ActivationReloadGate()
    let started = gate.beginReload(at: at(9, 0), calendar: paris)
    #expect(started)
    gate.noteExternalChange()
    gate.endReload(at: at(9, 0))
    #expect((activate(&gate, at: at(9, 1)) as Bool))
    #expect(!(activate(&gate, at: at(9, 2)) as Bool))
}

/// Un changement extérieur noté avant le retour est lu par la relecture de ce retour : il ne relance pas le suivant.
@Test func anExternalChangeBeforeTheReloadIsConsumedByIt() {
    var gate = ActivationReloadGate()
    #expect((activate(&gate, at: at(9, 0)) as Bool))
    gate.noteExternalChange()
    #expect((activate(&gate, at: at(9, 1)) as Bool))
    #expect(!(activate(&gate, at: at(9, 2)) as Bool))
}

/// Un retour pendant une relecture en cours ne la double pas.
@Test func anActivationDuringAReloadIsSkipped() {
    var gate = ActivationReloadGate()
    let first = gate.beginReload(at: at(9, 0), calendar: paris)
    let second = gate.beginReload(at: at(9, 0), calendar: paris)
    #expect(first && !second)
    gate.endReload(at: at(9, 0))
}

/// L'horloge a reculé (réglage manuel, fuseau) : la dernière relecture est « dans le futur », on relit.
@Test func aClockThatWentBackReloads() {
    var gate = ActivationReloadGate()
    #expect((activate(&gate, at: at(9, 0)) as Bool))
    #expect((activate(&gate, at: at(8, 30)) as Bool))
}
