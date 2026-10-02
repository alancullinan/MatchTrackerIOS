import Foundation

/// A reusable team sheet: exactly `size` slots, where the slot is the jersey
/// number. Empty slots are kept; panels are never sorted or compacted.
public struct PlayerPanel: Hashable, Sendable, Codable {
    public static let size = 30

    public var id: PanelID
    /// The PWA's id for a panel brought in by the one-time import; `nil` otherwise.
    public var legacyID: String?
    public var name: String
    public var createdAt: Date?
    public var slots: [PanelSlot]

    public init(id: PanelID = PanelID(), legacyID: String? = nil, name: String, createdAt: Date? = nil, slots: [PanelSlot]) {
        self.id = id
        self.legacyID = legacyID
        self.name = name
        self.createdAt = createdAt
        self.slots = slots
    }

    /// A panel with `size` empty slots, numbered from 1.
    public static func empty(name: String, createdAt: Date? = nil) -> PlayerPanel {
        PlayerPanel(name: name, createdAt: createdAt, slots: (1...size).map { PanelSlot(jerseyNumber: $0) })
    }
}

public struct PanelSlot: Hashable, Sendable, Codable {
    public var jerseyNumber: Int
    /// `nil` for an empty slot.
    public var name: String?

    /// A blank or whitespace-only name becomes `nil`.
    public init(jerseyNumber: Int, name: String? = nil) {
        self.jerseyNumber = jerseyNumber
        self.name = Player.cleaned(name)
    }
}
