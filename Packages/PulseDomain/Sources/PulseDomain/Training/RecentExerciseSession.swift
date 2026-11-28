import Foundation

/// Une séance passée vue depuis un de ses exercices : sa date, si elle a été faite en décharge, les séries hors échauffement de
/// l'exercice dans l'ordre, et la note de l'exercice. Les charges proposées en lisent la pause et les échecs répétés, la
/// séance suivante en reprend la note.
public struct RecentExerciseSession: Sendable, Equatable {
    public var startedAt: Date
    public var isDeloaded: Bool
    public var sets: [WorkoutSet]
    public var note: String?

    public init(startedAt: Date, isDeloaded: Bool = false, sets: [WorkoutSet], note: String? = nil) {
        self.startedAt = startedAt
        self.isDeloaded = isDeloaded
        self.sets = sets
        self.note = note
    }

    /// La même lecture sur une séance entière : `nil` quand elle n'a aucune série hors échauffement de l'exercice.
    public init?(_ session: WorkoutSession, exercise: ExerciseReference) {
        let sets = session.sets.filter { $0.exercise == exercise && $0.setType != .warmup }.sorted { $0.order < $1.order }
        guard !sets.isEmpty else { return nil }
        let note = session.exerciseNotes.first { $0.exercise == exercise }?.text
        self.init(startedAt: session.startedAt, isDeloaded: session.isDeloaded, sets: sets,
                  note: note?.isEmpty == false ? note : nil)
    }
}
