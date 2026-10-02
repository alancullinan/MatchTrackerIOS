import Foundation

/// A typed id: a `UUID` that can't be mixed up with another kind of id.
/// Encodes as a bare UUID string.
public struct Identifier<Tag>: Hashable, Sendable, Codable, CustomStringConvertible {
    public var uuid: UUID

    /// A new random id.
    public init() {
        uuid = UUID()
    }

    public init(_ uuid: UUID) {
        self.uuid = uuid
    }

    public init(from decoder: Decoder) throws {
        uuid = try decoder.singleValueContainer().decode(UUID.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uuid)
    }

    public var description: String { uuid.uuidString }
}

public enum MatchTag {}
public enum PlayerTag {}
public enum EventTag {}
public enum PanelTag {}

public typealias MatchID = Identifier<MatchTag>
public typealias PlayerID = Identifier<PlayerTag>
public typealias EventID = Identifier<EventTag>
public typealias PanelID = Identifier<PanelTag>
