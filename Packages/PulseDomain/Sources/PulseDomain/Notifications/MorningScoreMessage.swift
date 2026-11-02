/// Le texte de la notification du score du matin.
public struct MorningScoreMessage: Sendable, Equatable {
    public var title: String
    public var body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}
