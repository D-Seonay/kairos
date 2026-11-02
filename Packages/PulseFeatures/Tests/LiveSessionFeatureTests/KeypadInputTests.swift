@testable import LiveSessionFeature
import Testing

@Test func keypadBuildsFrenchDecimalsAndSteps() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: 70)
    #expect(input.apply(.minus) == 67.5)
    input.start(with: nil)
    _ = input.apply(.digit(7)); _ = input.apply(.digit(2)); _ = input.apply(.comma); _ = input.apply(.comma)
    #expect(input.apply(.digit(5)) == 72.5)
    #expect(input.text == "72,5")
}

@Test func startingOnAValueShowsItAndTheFirstDigitReplacesIt() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: 67.5)
    #expect(input.text == "67,5")
    #expect(input.apply(.digit(8)) == 8)
    #expect(input.text == "8")
    #expect(input.apply(.digit(0)) == 80)
}

@Test func startingOnNothingShowsAnEmptyBuffer() {
    var input = KeypadInput(field: .reps, increment: 2.5)
    input.start(with: nil)
    #expect(input.text.isEmpty)
    #expect(input.apply(.next) == nil)
}

@Test func deletingErasesDigitByDigitUntilNothingIsLeft() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: 72.5)
    #expect(input.apply(.delete) == 72)
    #expect(input.text == "72,")
    #expect(input.apply(.delete) == 72)
    #expect(input.text == "72")
    #expect(input.apply(.delete) == 7)
    #expect(input.apply(.delete) == nil)
    #expect(input.apply(.delete) == nil)
    #expect(input.text.isEmpty)
}

@Test func weightKeepsTwoDecimalsAtMost() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: nil)
    for key: KeypadInput.Key in [.digit(6), .comma, .digit(2), .digit(5), .digit(9)] { _ = input.apply(key) }
    #expect(input.text == "6,25")
    #expect(input.apply(.digit(1)) == 6.25)
}

@Test func aLoneCommaStartsAtZero() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: nil)
    #expect(input.apply(.comma) == 0)
    #expect(input.text == "0,")
    #expect(input.apply(.digit(5)) == 0.5)
}

@Test func aLeadingZeroIsReplacedByTheNextDigit() {
    var input = KeypadInput(field: .reps, increment: 2.5)
    input.start(with: nil)
    _ = input.apply(.digit(0))
    #expect(input.apply(.digit(8)) == 8)
    #expect(input.text == "8")
}

@Test func repsAndSecondsTakeNoComma() {
    for field in [KeypadField.Kind.reps, .duration] {
        var input = KeypadInput(field: field, increment: 2.5)
        input.start(with: nil)
        _ = input.apply(.digit(1))
        #expect(input.apply(.comma) == 1)
        #expect(input.text == "1")
    }
}

@Test func stepsRoundToAQuarterKilogramAndNeverGoBelowZero() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: 71.1)
    #expect(input.apply(.plus) == 73.5)
    input.start(with: 1)
    #expect(input.apply(.minus) == 0)
    #expect(input.text == "0")
    input.start(with: nil)
    #expect(input.apply(.plus) == 2.5)
    var fine = KeypadInput(field: .weight, increment: 0.5)
    fine.start(with: 20.1)
    #expect(fine.apply(.plus) == 20.5)
}

@Test func stepsApplyToTheBufferNotToThePreviousValue() {
    var input = KeypadInput(field: .weight, increment: 2.5)
    input.start(with: 70)
    _ = input.apply(.delete)
    _ = input.apply(.delete)
    #expect(input.apply(.digit(5)) == 5)
    #expect(input.apply(.plus) == 7.5)
}

@Test func repsStepByOneAndSecondsByFive() {
    var reps = KeypadInput(field: .reps, increment: 2.5)
    reps.start(with: 8)
    #expect(reps.apply(.plus) == 9)
    #expect(reps.apply(.minus) == 8)
    var seconds = KeypadInput(field: .duration, increment: 2.5)
    seconds.start(with: 30)
    #expect(seconds.apply(.plus) == 35)
}

@Test func digitsAreCappedSoNothingOverflows() {
    var input = KeypadInput(field: .reps, increment: 2.5)
    input.start(with: nil)
    for digit in 1...6 { _ = input.apply(.digit(digit)) }
    #expect(input.text == "123")
}

@Test func aCommaOnRepsOrSecondsKeepsTheValueThatWaitsToBeReplaced() {
    for field in [KeypadField.Kind.reps, .duration] {
        var input = KeypadInput(field: field, increment: 2.5)
        input.start(with: 8)
        #expect(input.apply(.comma) == 8)
        #expect(input.text == "8")
        #expect(input.apply(.digit(5)) == 5)
    }
}
