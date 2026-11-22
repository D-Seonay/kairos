import SwiftUI
import Testing

@testable import PulseDesignSystem

@Test func reducedMotionRemovesTheAnimation() {
    #expect(PulseMotion.resolved(.snappy, reduceMotion: true) == nil)
    #expect(PulseMotion.resolved(.snappy, reduceMotion: false) != nil)
    #expect(PulseMotion.resolved(nil, reduceMotion: false) == nil)
}

@Test func reducedMotionTurnsTransitionsIntoAFade() {
    let slide = AnyTransition.move(edge: .bottom).combined(with: .opacity)
    #expect(String(describing: PulseMotion.resolved(slide, reduceMotion: true)) == String(describing: AnyTransition.opacity))
    #expect(String(describing: PulseMotion.resolved(slide, reduceMotion: false)) == String(describing: slide))
}

@MainActor
@Test func performRunsTheBodyEitherWay() {
    var runs = 0
    PulseMotion.perform(.snappy, reduceMotion: true) { runs += 1 }
    PulseMotion.perform(.snappy, reduceMotion: false) { runs += 1 }
    PulseMotion.perform(nil, reduceMotion: false) { runs += 1 }
    #expect(runs == 3)
}
