@testable import CheckInFeature
import PulseDomain
import Testing

@Test func optionsMapToEngineValues() {
    #expect(CheckInQuestion.sleep.options.map(\.value) == [0, 1, 2, 3, 4])
    #expect(CheckInQuestion.pain.options.map(\.value) == [4, 3, 2, 1, 0])
    #expect(CheckInQuestion.motivation.options.map(\.value) == [0, 1, 2, 3, 4])
}

@Test @MainActor func incompleteFormHasNoScore() {
    let form = CheckInForm()
    form.selection[.sleep] = 3
    #expect(form.estimatedScore == nil)
    #expect(form.answers == nil)
}

@Test @MainActor func completeFormScoresLive() {
    let form = CheckInForm()
    form.selection = [.sleep: 3, .pain: 3, .motivation: 3]
    #expect(form.estimatedScore == 75)
    #expect(form.answers == CheckInAnswers(sleep: 3, pain: 3, motivation: 3))
}
