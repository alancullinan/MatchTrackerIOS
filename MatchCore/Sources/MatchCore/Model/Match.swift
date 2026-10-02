import Foundation

public struct Match: Hashable, Sendable, Codable {
    public var id: MatchID
    /// The PWA's id for a match brought in by the one-time import; `nil` otherwise.
    public var legacyID: String?
    public var matchType: MatchType
    public var competition: String
    public var date: Date
    public var venue: String
    public var referee: String
    /// Minutes.
    public var halfLength: Int
    /// Minutes.
    public var extraHalfLength: Int
    public var team1: Team
    public var team2: Team
    public var events: [MatchEvent]
    public var clock: MatchClock
    /// Firebase live-score id, once the match has been shared.
    public var liveShareID: String?

    public init(
        id: MatchID = MatchID(),
        legacyID: String? = nil,
        matchType: MatchType,
        competition: String,
        date: Date,
        venue: String,
        referee: String,
        halfLength: Int,
        extraHalfLength: Int,
        team1: Team,
        team2: Team,
        events: [MatchEvent] = [],
        clock: MatchClock = MatchClock(),
        liveShareID: String? = nil
    ) {
        self.id = id
        self.legacyID = legacyID
        self.matchType = matchType
        self.competition = competition
        self.date = date
        self.venue = venue
        self.referee = referee
        self.halfLength = halfLength
        self.extraHalfLength = extraHalfLength
        self.team1 = team1
        self.team2 = team2
        self.events = events
        self.clock = clock
        self.liveShareID = liveShareID
    }

    /// A match not yet started, with two full rosters of unnamed players.
    /// Default half lengths are the PWA's: 30 and 10 minutes.
    public static func new(
        matchType: MatchType,
        team1Name: String,
        team2Name: String,
        competition: String = "",
        date: Date,
        venue: String = "",
        referee: String = "",
        halfLength: Int = 30,
        extraHalfLength: Int = 10
    ) -> Match {
        Match(
            matchType: matchType,
            competition: competition,
            date: date,
            venue: venue,
            referee: referee,
            halfLength: halfLength,
            extraHalfLength: extraHalfLength,
            team1: .roster(name: team1Name),
            team2: .roster(name: team2Name)
        )
    }

    public subscript(side: TeamSide) -> Team {
        get {
            switch side {
            case .team1: team1
            case .team2: team2
            }
        }
        set {
            switch side {
            case .team1: team1 = newValue
            case .team2: team2 = newValue
            }
        }
    }
}
