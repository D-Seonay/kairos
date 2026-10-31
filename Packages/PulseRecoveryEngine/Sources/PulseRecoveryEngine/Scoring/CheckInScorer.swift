/// Réponses du check-in du matin, chacune de 0 à 4, 4 étant le meilleur état.
public struct CheckInAnswers: Sendable, Equatable, Codable {
    public var sleep: Int
    public var pain: Int
    public var motivation: Int

    public init(sleep: Int, pain: Int, motivation: Int) {
        self.sleep = sleep
        self.pain = pain
        self.motivation = motivation
    }
}

/// Score de check-in pondéré sommeil 40 / douleur 35 / motivation 25.
public enum CheckInScorer {
    public static func score(_ answers: CheckInAnswers) -> Double {
        normalized(answers.sleep) * 0.40 + normalized(answers.pain) * 0.35 + normalized(answers.motivation) * 0.25
    }

    private static func normalized(_ answer: Int) -> Double {
        Double(min(4, max(0, answer))) * 25
    }
}
