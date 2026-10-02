import Foundation

public struct Player: Hashable, Sendable, Codable {
    public var id: PlayerID
    public var jerseyNumber: Int
    /// `nil` for an unnamed player; never a `No.N` placeholder.
    public var name: String?

    /// A blank or whitespace-only name becomes `nil`.
    public init(id: PlayerID = PlayerID(), jerseyNumber: Int, name: String? = nil) {
        self.id = id
        self.jerseyNumber = jerseyNumber
        self.name = Player.cleaned(name)
    }

    static func cleaned(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
