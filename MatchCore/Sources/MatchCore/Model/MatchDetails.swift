import Foundation

/// The parts of a match set when it is created and changed by editing it:
/// everything except the players, events and clock. Team colours can change
/// at any time.
public struct MatchDetails: Hashable, Sendable {
    public var matchType: MatchType
    public var team1Name: String
    public var team2Name: String
    public var team1Colors: TeamColors?
    public var team2Colors: TeamColors?
    public var competition: String
    public var date: Date
    public var venue: String
    public var referee: String

    public init(
        matchType: MatchType = .football,
        team1Name: String = "",
        team2Name: String = "",
        team1Colors: TeamColors? = nil,
        team2Colors: TeamColors? = nil,
        competition: String = "",
        date: Date,
        venue: String = "",
        referee: String = ""
    ) {
        self.matchType = matchType
        self.team1Name = team1Name
        self.team2Name = team2Name
        self.team1Colors = team1Colors
        self.team2Colors = team2Colors
        self.competition = competition
        self.date = date
        self.venue = venue
        self.referee = referee
    }

    /// Both teams are named. The other fields are optional.
    public var isComplete: Bool {
        !Self.trimmed(team1Name).isEmpty && !Self.trimmed(team2Name).isEmpty
    }

    /// The same details with surrounding spaces removed from every text field.
    public var trimmed: MatchDetails {
        var details = self
        details.team1Name = Self.trimmed(team1Name)
        details.team2Name = Self.trimmed(team2Name)
        details.competition = Self.trimmed(competition)
        details.venue = Self.trimmed(venue)
        details.referee = Self.trimmed(referee)
        return details
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension MatchType {
    /// The name to show.
    public var displayName: String {
        switch self {
        case .football: "Football"
        case .hurling: "Hurling"
        case .ladiesFootball: "Ladies Football"
        case .camogie: "Camogie"
        }
    }
}

extension Match {
    /// A match not yet started, from complete details; `nil` if a team is unnamed.
    public static func new(_ details: MatchDetails) -> Match? {
        guard details.isComplete else { return nil }
        let details = details.trimmed
        var match = Match.new(
            matchType: details.matchType,
            team1Name: details.team1Name,
            team2Name: details.team2Name,
            competition: details.competition,
            date: details.date,
            venue: details.venue,
            referee: details.referee
        )
        match.team1.colors = details.team1Colors
        match.team2.colors = details.team2Colors
        return match
    }

    public var details: MatchDetails {
        MatchDetails(
            matchType: matchType,
            team1Name: team1.name,
            team2Name: team2.name,
            team1Colors: team1.colors,
            team2Colors: team2.colors,
            competition: competition,
            date: date,
            venue: venue,
            referee: referee
        )
    }

    /// The code can change only before throw-in: scores already recorded
    /// depend on it (two-pointers exist only in football codes).
    public var canChangeMatchType: Bool {
        clock.period == .notStarted && events.isEmpty
    }

    /// Applies edited details. Players, events and the clock are untouched.
    /// Returns `false` and changes nothing if a team is unnamed, or if the
    /// code would change after throw-in.
    @discardableResult
    public mutating func apply(_ details: MatchDetails) -> Bool {
        guard details.isComplete else { return false }
        guard details.matchType == matchType || canChangeMatchType else { return false }
        let details = details.trimmed
        matchType = details.matchType
        team1.name = details.team1Name
        team2.name = details.team2Name
        team1.colors = details.team1Colors
        team2.colors = details.team2Colors
        competition = details.competition
        date = details.date
        venue = details.venue
        referee = details.referee
        return true
    }
}
