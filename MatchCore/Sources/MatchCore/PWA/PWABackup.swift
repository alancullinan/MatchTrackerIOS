import Foundation

// The PWA's backup format, mirrored exactly. Used only to import PWA backups
// (and, for live sharing, to write the PWA's match shape); the app's own model
// lives in Model/. PWA quirks are converted by the importer, not here.
//
// Dates stay in the PWA's string form (`dateTime` is "YYYY-MM-DD", the others
// ISO-8601) so they write back out unchanged.
//
// Decoding is lenient: only what the PWA's own import requires is required,
// unknown keys are ignored, and missing fields take the PWA's defaults.
// Encoding writes `null` and omits keys exactly where the PWA does.

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(type, forKey: key) ?? defaultValue
    }
}

/// An event id. The PWA's ids are strings (`"1727771234567-123456"`), except
/// period-end events, whose ids are numbers (`Date.now()`).
public enum PWAEventID: Hashable, Sendable, Codable {
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

public struct PWAPlayer: Hashable, Sendable, Codable {
    public var id: String
    /// As stored: an unnamed player is `"No.<jerseyNumber>"`. `nil` only if the key is missing.
    public var name: String?
    public var jerseyNumber: Int
    public var position: String

    public init(id: String, name: String?, jerseyNumber: Int, position: String = "") {
        self.id = id
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.position = position
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        jerseyNumber = try container.decode(Int.self, forKey: .jerseyNumber)
        position = try container.decode(String.self, forKey: .position, default: "")
    }
}

public struct PWATeam: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    /// 30 players, jersey numbers 1-30.
    public var players: [PWAPlayer]

    public init(id: String, name: String, players: [PWAPlayer]) {
        self.id = id
        self.name = name
        self.players = players
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name, default: "")
        players = try container.decode([PWAPlayer].self, forKey: .players, default: [])
    }
}

public struct PWAEvent: Hashable, Sendable, Codable {
    public var id: PWAEventID
    public var type: PWAEventType
    public var period: PWAPeriod
    /// Seconds into `period`.
    public var timeElapsed: Int
    // Period-end events have none of the fields below.
    public var teamId: String?
    public var player1Id: String?
    /// The player coming on, for a substitution.
    public var player2Id: String?
    public var shotOutcome: PWAShotOutcome?
    public var shotType: PWAShotType?
    public var foulOutcome: PWAFoulOutcome?
    public var cardType: PWACardType?
    public var wonKickout: Bool?
    public var noteText: String?

    public init(
        id: PWAEventID,
        type: PWAEventType,
        period: PWAPeriod,
        timeElapsed: Int,
        teamId: String? = nil,
        player1Id: String? = nil,
        player2Id: String? = nil,
        shotOutcome: PWAShotOutcome? = nil,
        shotType: PWAShotType? = nil,
        foulOutcome: PWAFoulOutcome? = nil,
        cardType: PWACardType? = nil,
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

    private enum CodingKeys: String, CodingKey {
        case id, type, period, timeElapsed, teamId, player1Id, player2Id
        case shotOutcome, shotType, foulOutcome, cardType, wonKickout, noteText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(PWAEventID.self, forKey: .id)
        type = try container.decode(PWAEventType.self, forKey: .type)
        period = try container.decode(PWAPeriod.self, forKey: .period)
        timeElapsed = try container.decode(Int.self, forKey: .timeElapsed, default: 0)
        teamId = try container.decodeIfPresent(String.self, forKey: .teamId)
        player1Id = try container.decodeIfPresent(String.self, forKey: .player1Id)
        player2Id = try container.decodeIfPresent(String.self, forKey: .player2Id)
        shotOutcome = try container.decodeIfPresent(PWAShotOutcome.self, forKey: .shotOutcome)
        shotType = try container.decodeIfPresent(PWAShotType.self, forKey: .shotType)
        foulOutcome = try container.decodeIfPresent(PWAFoulOutcome.self, forKey: .foulOutcome)
        cardType = try container.decodeIfPresent(PWACardType.self, forKey: .cardType)
        wonKickout = try container.decodeIfPresent(Bool.self, forKey: .wonKickout)
        noteText = try container.decodeIfPresent(String.self, forKey: .noteText)
    }

    /// Period-end events have only id, type, period and timeElapsed; every
    /// other event writes all its fields, with `null` for empty ones.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(period, forKey: .period)
        try container.encode(timeElapsed, forKey: .timeElapsed)
        guard type != .periodEnd else { return }
        try container.encode(teamId, forKey: .teamId)
        try container.encode(player1Id, forKey: .player1Id)
        try container.encode(player2Id, forKey: .player2Id)
        try container.encode(shotOutcome, forKey: .shotOutcome)
        try container.encode(shotType, forKey: .shotType)
        try container.encode(foulOutcome, forKey: .foulOutcome)
        try container.encode(cardType, forKey: .cardType)
        try container.encode(wonKickout, forKey: .wonKickout)
        try container.encode(noteText, forKey: .noteText)
    }
}

public struct PWAMatch: Hashable, Sendable, Codable {
    public var id: String
    public var competition: String
    /// "YYYY-MM-DD", as entered in the PWA's date field.
    public var dateTime: String
    public var venue: String
    public var referee: String
    public var matchType: PWAMatchType
    /// Minutes. Stored by the PWA but not used by its timer.
    public var halfLength: Int
    public var extraHalfLength: Int
    public var team1: PWATeam
    public var team2: PWATeam
    public var events: [PWAEvent]
    public var currentPeriod: PWAPeriod
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
        matchType: PWAMatchType,
        halfLength: Int,
        extraHalfLength: Int,
        team1: PWATeam,
        team2: PWATeam,
        events: [PWAEvent] = [],
        currentPeriod: PWAPeriod = .notStarted,
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

    private enum CodingKeys: String, CodingKey {
        case id, competition, dateTime, venue, referee, matchType, halfLength, extraHalfLength
        case team1, team2, events, currentPeriod, elapsedTime, isPaused, periodStartTimestamp
        case shareId, isBroadcasting
    }

    /// Defaults are the PWA's new-match values.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        competition = try container.decode(String.self, forKey: .competition, default: "")
        dateTime = try container.decode(String.self, forKey: .dateTime, default: "")
        venue = try container.decode(String.self, forKey: .venue, default: "")
        referee = try container.decode(String.self, forKey: .referee, default: "")
        matchType = try container.decode(PWAMatchType.self, forKey: .matchType, default: .football)
        halfLength = try container.decode(Int.self, forKey: .halfLength, default: 30)
        extraHalfLength = try container.decode(Int.self, forKey: .extraHalfLength, default: 10)
        team1 = try container.decode(PWATeam.self, forKey: .team1)
        team2 = try container.decode(PWATeam.self, forKey: .team2)
        events = try container.decode([PWAEvent].self, forKey: .events, default: [])
        currentPeriod = try container.decode(PWAPeriod.self, forKey: .currentPeriod, default: .notStarted)
        elapsedTime = try container.decode(Int.self, forKey: .elapsedTime, default: 0)
        isPaused = try container.decode(Bool.self, forKey: .isPaused, default: true)
        periodStartTimestamp = try container.decodeIfPresent(Int64.self, forKey: .periodStartTimestamp)
        shareId = try container.decodeIfPresent(String.self, forKey: .shareId)
        isBroadcasting = try container.decodeIfPresent(Bool.self, forKey: .isBroadcasting)
    }

    /// `periodStartTimestamp` is always written (`null` when stopped);
    /// `shareId` and `isBroadcasting` only once a match has been shared.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(competition, forKey: .competition)
        try container.encode(dateTime, forKey: .dateTime)
        try container.encode(venue, forKey: .venue)
        try container.encode(referee, forKey: .referee)
        try container.encode(matchType, forKey: .matchType)
        try container.encode(halfLength, forKey: .halfLength)
        try container.encode(extraHalfLength, forKey: .extraHalfLength)
        try container.encode(team1, forKey: .team1)
        try container.encode(team2, forKey: .team2)
        try container.encode(events, forKey: .events)
        try container.encode(currentPeriod, forKey: .currentPeriod)
        try container.encode(elapsedTime, forKey: .elapsedTime)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(periodStartTimestamp, forKey: .periodStartTimestamp)
        try container.encodeIfPresent(shareId, forKey: .shareId)
        try container.encodeIfPresent(isBroadcasting, forKey: .isBroadcasting)
    }
}

/// One slot of a panel. Legacy panels have no jersey numbers; an empty slot has name "".
public struct PWAPanelPlayer: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var jerseyNumber: Int?

    public init(id: String, name: String, jerseyNumber: Int?) {
        self.id = id
        self.name = name
        self.jerseyNumber = jerseyNumber
    }
}

public struct PWAPanel: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var players: [PWAPanelPlayer]
    /// ISO-8601. Missing on legacy panels.
    public var createdDate: String?

    public init(id: String, name: String, players: [PWAPanelPlayer], createdDate: String? = nil) {
        self.id = id
        self.name = name
        self.players = players
        self.createdDate = createdDate
    }
}

/// The PWA's export file. `matchCount` and `panelCount` are derived when writing.
public struct PWABackup: Hashable, Sendable, Codable {
    public var version: String
    /// ISO-8601 with milliseconds, e.g. "2026-10-01T20:39:21.651Z".
    public var exportDate: String
    public var matches: [PWAMatch]
    public var playerPanels: [PWAPanel]
    /// Last panel chosen per team, keyed `"<matchId>-team1"` / `"<matchId>-team2"`, valued by panel id.
    public var lastSelectedPanels: [String: String]

    public init(
        version: String = "1.0.0",
        exportDate: String,
        matches: [PWAMatch],
        playerPanels: [PWAPanel],
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
        // Only `matches` is required, as in the PWA's import.
        version = try container.decode(String.self, forKey: .version, default: "1.0.0")
        exportDate = try container.decode(String.self, forKey: .exportDate, default: "")
        matches = try container.decode([PWAMatch].self, forKey: .matches)
        playerPanels = try container.decode([PWAPanel].self, forKey: .playerPanels, default: [])
        // Only a remembered choice; a malformed one is not worth failing an import over.
        lastSelectedPanels = (try? container.decode([String: String].self, forKey: .lastSelectedPanels, default: [:])) ?? [:]
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
