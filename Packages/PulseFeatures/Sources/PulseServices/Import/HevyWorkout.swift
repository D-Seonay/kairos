import Foundation

/// Les séries consécutives d'un même exercice dans une séance.
public struct HevyExerciseBlock: Sendable, Equatable {
    public let name: String
    public let notes: String?
    public let supersetID: Int?
    public let sets: [HevyRow]
}

public struct HevyWorkout: Sendable, Equatable {
    public let title: String
    public let startedAt: Date
    public let endedAt: Date
    public let description: String?
    public let exercises: [HevyExerciseBlock]
}

public enum HevyWorkouts {
    private struct Key: Hashable {
        let title: String
        let startedAt: Date
        let endedAt: Date
    }

    /// Une séance par (`title`, `startedAt`, `endedAt`), triées par début croissant (à égalité, dans l'ordre de l'export) ;
    /// une séance compte un bloc par suite de lignes consécutives du même exercice.
    public static func group(_ rows: [HevyRow]) -> [HevyWorkout] {
        var order: [Key] = []
        var grouped: [Key: [HevyRow]] = [:]
        for row in rows {
            let key = Key(title: row.title, startedAt: row.startedAt, endedAt: row.endedAt)
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(row)
        }
        return order.enumerated()
            .sorted { ($0.element.startedAt, $0.offset) < ($1.element.startedAt, $1.offset) }
            .compactMap { _, key in grouped[key].flatMap(workout) }
    }

    private static func workout(_ rows: [HevyRow]) -> HevyWorkout? {
        guard let first = rows.first else { return nil }
        return HevyWorkout(title: first.title, startedAt: first.startedAt, endedAt: first.endedAt,
                           description: first.description, exercises: blocks(rows))
    }

    private static func blocks(_ rows: [HevyRow]) -> [HevyExerciseBlock] {
        var runs: [[HevyRow]] = []
        for row in rows {
            if runs.last?.last?.exerciseTitle == row.exerciseTitle {
                runs[runs.count - 1].append(row)
            } else {
                runs.append([row])
            }
        }
        return runs.map { run in
            HevyExerciseBlock(name: run[0].exerciseTitle, notes: run[0].exerciseNotes, supersetID: run[0].supersetID, sets: run)
        }
    }
}
