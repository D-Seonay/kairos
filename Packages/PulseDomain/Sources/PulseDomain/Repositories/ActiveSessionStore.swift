public protocol ActiveSessionStore: Sendable {
    func load() async throws -> ActiveSessionSnapshot?
    func save(_ snapshot: ActiveSessionSnapshot) async throws
    func clear() async throws
}
