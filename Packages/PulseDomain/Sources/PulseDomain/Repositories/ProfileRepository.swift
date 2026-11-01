public protocol ProfileRepository: Sendable {
    /// Le profil, ou le plus ancien s'il en existe plusieurs après une restauration.
    func load() async throws -> UserProfile?
    func save(_ profile: UserProfile) async throws
}
