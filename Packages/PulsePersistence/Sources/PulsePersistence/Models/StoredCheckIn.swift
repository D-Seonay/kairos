import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredCheckIn {
    public var id: UUID = UUID()
    public var day: Date = Date()
    public var sleepAnswer: Int = 0
    public var painAnswer: Int = 0
    public var motivationAnswer: Int = 0
    public var score: Double = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?
    /// Le jour civil, « 2026-11-27 », arrivé en V9 ; `nil` comme pour `StoredDailyRecovery.dayKey`.
    public var dayKey: String?

    public init(_ checkIn: CheckIn) {
        id = checkIn.id
        createdAt = checkIn.createdAt
        apply(checkIn)
    }

    public func apply(_ checkIn: CheckIn) {
        day = checkIn.day
        sleepAnswer = checkIn.answers.sleep
        painAnswer = checkIn.answers.pain
        motivationAnswer = checkIn.answers.motivation
        score = checkIn.score
        updatedAt = checkIn.updatedAt
    }

    public func toDomain() -> CheckIn {
        CheckIn(id: id, day: day, answers: CheckInAnswers(sleep: sleepAnswer, pain: painAnswer, motivation: motivationAnswer),
                score: score, createdAt: createdAt, updatedAt: updatedAt)
    }
}
