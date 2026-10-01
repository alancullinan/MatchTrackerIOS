import Foundation

// Value-type mirrors of the PWA's stored objects. Property names are the PWA's
// JSON keys, so a backup decodes straight into these types.
//
// Dates stay in the PWA's string form (`dateTime` is "YYYY-MM-DD", the others
// ISO-8601) so they write back out unchanged.

/// An event id. The PWA's ids are strings (`"1727771234567-123456"`), except
/// period-end events, whose ids are numbers (`Date.now()`).
public enum EventID: Hashable, Sendable, Codable {
    case string(String)
    case number(Int64)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            self = .number(try container.decode(Int64.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string): try container.encode(string)
        case .number(let number): try container.encode(number)
        }
    }
}

public struct Player: Hashable, Sendable, Codable {
    public var id: String
    /// `nil` when the player still has the PWA's default name, `No.<jerseyNumber>`.
    public var name: String?
    public var jerseyNumber: Int
    public var position: String

    public init(id: String, name: String? = nil, jerseyNumber: Int, position: String = "") {
        self.id = id
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.position = position
    }

    /// The name as the PWA stores it: the real name, or `No.<jerseyNumber>`.
    public var storedName: String {
        name ?? Self.defaultName(jerseyNumber: jerseyNumber)
    }

    static func defaultName(jerseyNumber: Int) -> String {
        "No.\(jerseyNumber)"
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, jerseyNumber, position
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        jerseyNumber = try container.decode(Int.self, forKey: .jerseyNumber)
        position = try container.decode(String.self, forKey: .position)
        let stored = try container.decode(String.self, forKey: .name)
        name = stored == Self.defaultName(jerseyNumber: jerseyNumber) ? nil : stored
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(storedName, forKey: .name)
        try container.encode(jerseyNumber, forKey: .jerseyNumber)
        try container.encode(position, forKey: .position)
    }
}

public struct Team: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    /// 30 players, jersey numbers 1-30.
    public var players: [Player]

    public init(id: String, name: String, players: [Player]) {
        self.id = id
        self.name = name
        self.players = players
    }
}

public struct MatchEvent: Hashable, Sendable, Codable {
    public var id: EventID
    public var type: EventType
    public var period: MatchPeriod
    /// Seconds into `period`.
    public var timeElapsed: Int
    // Period-end events have none of the fields below.
    public var teamId: String?
    public var player1Id: String?
    /// The player coming on, for a substitution.
    public var player2Id: String?
    public var shotOutcome: ShotOutcome?
    public var shotType: ShotType?
    public var foulOutcome: FoulOutcome?
    public var cardType: CardType?
    public var wonKickout: Bool?
    public var noteText: String?

    public init(
        id: EventID,
        type: EventType,
        period: MatchPeriod,
        timeElapsed: Int,
        teamId: String? = nil,
        player1Id: String? = nil,
        player2Id: String? = nil,
        shotOutcome: ShotOutcome? = nil,
        shotType: ShotType? = nil,
        foulOutcome: FoulOutcome? = nil,
        cardType: CardType? = nil,
        wonKickout: Bool? = nil,
        noteText: String? = nil
    ) {
        self.id = id
        self.type = type
        self.period = period
        self.timeElapsed = timeElapsed
        self.teamId = teamId
        self.player1Id = player1Id
        self.player2Id = player2Id
        self.shotOutcome = shotOutcome
        self.shotType = shotType
        self.foulOutcome = foulOutcome
        self.cardType = cardType
        self.wonKickout = wonKickout
        self.noteText = noteText
    }
}

public struct Match: Hashable, Sendable, Codable {
    public var id: String
    public var competition: String
    /// "YYYY-MM-DD", as entered in the PWA's date field.
    public var dateTime: String
    public var venue: String
    public var referee: String
    public var matchType: MatchType
    /// Minutes. Stored by the PWA but not used by its timer.
    public var halfLength: Int
    public var extraHalfLength: Int
    public var team1: Team
    public var team2: Team
    public var events: [MatchEvent]
    public var currentPeriod: MatchPeriod
    /// Seconds into `currentPeriod`.
    public var elapsedTime: Int
    public var isPaused: Bool
    /// Epoch milliseconds when the running period started, or `nil`.
    public var periodStartTimestamp: Int64?
    /// Firebase live-share id; present only once a match has been shared.
    public var shareId: String?
    public var isBroadcasting: Bool?

    public init(
        id: String,
        competition: String,
        dateTime: String,
        venue: String,
        referee: String,
        matchType: MatchType,
        halfLength: Int,
        extraHalfLength: Int,
        team1: Team,
        team2: Team,
        events: [MatchEvent] = [],
        currentPeriod: MatchPeriod = .notStarted,
        elapsedTime: Int = 0,
        isPaused: Bool = true,
        periodStartTimestamp: Int64? = nil,
        shareId: String? = nil,
        isBroadcasting: Bool? = nil
    ) {
        self.id = id
        self.competition = competition
        self.dateTime = dateTime
        self.venue = venue
        self.referee = referee
        self.matchType = matchType
        self.halfLength = halfLength
        self.extraHalfLength = extraHalfLength
        self.team1 = team1
        self.team2 = team2
        self.events = events
        self.currentPeriod = currentPeriod
        self.elapsedTime = elapsedTime
        self.isPaused = isPaused
        self.periodStartTimestamp = periodStartTimestamp
        self.shareId = shareId
        self.isBroadcasting = isBroadcasting
    }
}

/// One slot of a panel. Legacy panels have no jersey numbers; an empty slot has name "".
public struct PanelPlayer: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var jerseyNumber: Int?

    public init(id: String, name: String, jerseyNumber: Int?) {
        self.id = id
        self.name = name
        self.jerseyNumber = jerseyNumber
    }
}

public struct PlayerPanel: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var players: [PanelPlayer]
    /// ISO-8601. Missing on legacy panels.
    public var createdDate: String?

    public init(id: String, name: String, players: [PanelPlayer], createdDate: String? = nil) {
        self.id = id
        self.name = name
        self.players = players
        self.createdDate = createdDate
    }
}

/// The PWA's export file. `matchCount` and `panelCount` are derived when writing.
public struct Backup: Hashable, Sendable, Codable {
    public var version: String
    /// ISO-8601 with milliseconds, e.g. "2026-10-01T20:39:21.651Z".
    public var exportDate: String
    public var matches: [Match]
    public var playerPanels: [PlayerPanel]
    /// Last panel chosen per team, keyed `"<matchId>-team1"` / `"<matchId>-team2"`, valued by panel id.
    public var lastSelectedPanels: [String: String]

    public init(
        version: String = "1.0.0",
        exportDate: String,
        matches: [Match],
        playerPanels: [PlayerPanel],
        lastSelectedPanels: [String: String]
    ) {
        self.version = version
        self.exportDate = exportDate
        self.matches = matches
        self.playerPanels = playerPanels
        self.lastSelectedPanels = lastSelectedPanels
    }

    public var matchCount: Int { matches.count }
    public var panelCount: Int { playerPanels.count }

    private enum CodingKeys: String, CodingKey {
        case version, exportDate, matches, matchCount, playerPanels, panelCount, lastSelectedPanels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        exportDate = try container.decode(String.self, forKey: .exportDate)
        matches = try container.decode([Match].self, forKey: .matches)
        playerPanels = try container.decode([PlayerPanel].self, forKey: .playerPanels)
        lastSelectedPanels = try container.decode([String: String].self, forKey: .lastSelectedPanels)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(exportDate, forKey: .exportDate)
        try container.encode(matches, forKey: .matches)
        try container.encode(matchCount, forKey: .matchCount)
        try container.encode(playerPanels, forKey: .playerPanels)
        try container.encode(panelCount, forKey: .panelCount)
        try container.encode(lastSelectedPanels, forKey: .lastSelectedPanels)
    }
}
