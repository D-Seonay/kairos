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

@Test func estimationIsReadOutOfOneHundredWithItsCategory() {
    #expect(CheckInText.estimation(score: 58.4, category: .moderateFatigue) == "Estimation : 58 sur 100, fatigue modérée")
    #expect(CheckInText.estimation(score: 75, category: .normal) == "Estimation : 75 sur 100, forme normale")
    #expect(CheckInText.estimation(score: 100, category: .optimal) == "Estimation : 100 sur 100, forme optimale")
    #expect(CheckInText.estimation(score: 25, category: .overreached) == "Estimation : 25 sur 100, surmenage")
}

@Test func estimationWithoutAScoreAsksForTheAnswers() {
    #expect(CheckInText.estimation(score: nil, category: nil) == "Estimation : réponds aux trois questions")
    #expect(CheckInText.estimation(score: .nan, category: .normal) == "Estimation : réponds aux trois questions")
}

@Test func estimationScoreIsBoundedToTheScale() {
    #expect(CheckInText.estimation(score: 140, category: .optimal) == "Estimation : 100 sur 100, forme optimale")
    #expect(CheckInText.estimation(score: -3, category: .overreached) == "Estimation : 0 sur 100, surmenage")
}

@Test func announcementIsTheEstimationOnceAvailable() {
    #expect(CheckInText.announcement(score: nil, category: nil) == nil)
    #expect(CheckInText.announcement(score: 75, category: .normal) == "Estimation : 75 sur 100, forme normale")
}
