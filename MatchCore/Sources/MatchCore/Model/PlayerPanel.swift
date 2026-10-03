import Foundation

/// A reusable team sheet: 30 slots, up to 40 like a team, where the slot is
/// the jersey number. Empty slots are kept; panels are never sorted or compacted.
public struct PlayerPanel: Identifiable, Hashable, Sendable, Codable {
    /// Slots a panel starts with, numbered 1 to 30, like a team.
    public static let startingSize = Team.startingRosterSize
    /// The most slots a panel can have: 31 to 40 are added on demand.
    public static let maxSize = Team.maxRosterSize

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

    /// A panel with `startingSize` empty slots, numbered from 1.
    public static func empty(name: String, createdAt: Date? = nil) -> PlayerPanel {
        PlayerPanel(name: name, createdAt: createdAt, slots: (1...startingSize).map { PanelSlot(jerseyNumber: $0) })
    }

    /// The slot that would be added next (the next jersey number), or `nil`
    /// once the panel has `maxSize` slots.
    public func nextExtraSlot() -> PanelSlot? {
        slots.count < Self.maxSize ? PanelSlot(jerseyNumber: slots.count + 1) : nil
    }

    /// How many slots have a name.
    public var namedCount: Int { slots.count { $0.name != nil } }

    /// Replaces the name and slots with edited ones. Returns `false`, changing
    /// nothing, unless the name isn't blank and the slots are numbered 1, 2, 3 ...
    /// in order, at least `startingSize` and at most `maxSize` of them. The name
    /// and slot names are cleaned: trimmed, and a blank slot name becomes `nil`.
    @discardableResult
    public mutating func update(name: String, slots: [PanelSlot]) -> Bool {
        guard let name = Player.cleaned(name),
              (Self.startingSize...Self.maxSize).contains(slots.count),
              slots.map(\.jerseyNumber) == Array(1...slots.count)
        else { return false }
        self.name = name
        self.slots = slots.map { PanelSlot(jerseyNumber: $0.jerseyNumber, name: $0.name) }
        return true
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
