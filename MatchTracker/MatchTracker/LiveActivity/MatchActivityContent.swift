import Foundation
import MatchCore

/// What a match's Live Activity shows, built from the match. Kept apart from
/// ActivityKit so it can be tested.
enum MatchActivityContent {
    /// Whether a match has a Live Activity: from throw-in until the match is
    /// over (Full Time, or Full Time after extra time). It shows through breaks.
    static func isLive(_ match: Match) -> Bool {
        switch match.clock.period {
        case .notStarted, .fullTime, .fullTimeAfterExtraTime: false
        case .firstHalf, .halfTime, .secondHalf, .extraTimeFirstHalf, .extraTimeHalfTime, .extraTimeSecondHalf: true
        }
    }

    static func attributes(for match: Match) -> MatchActivityAttributes {
        MatchActivityAttributes(matchID: match.id.uuid, competition: match.competition)
    }

    static func state(for match: Match) -> MatchActivityAttributes.ContentState {
        let clockZero = match.clockZero
        return MatchActivityAttributes.ContentState(
            team1: team(match, .team1),
            team2: team(match, .team2),
            periodName: match.clock.period.displayName,
            clockStartedAt: clockZero,
            // A stopped clock doesn't depend on the time, so any date gives the same text.
            stoppedClock: clockZero == nil ? match.clockText(at: .distantPast) : "",
            lastEvent: match.eventsInOrder.last.map { EventText.title($0, in: match) }
        )
    }

    private static func team(_ match: Match, _ side: TeamSide) -> MatchActivityAttributes.TeamLine {
        let score = match.score(side)
        let colors = match[side].colors
        return MatchActivityAttributes.TeamLine(
            name: EventText.teamName(match[side]),
            score: score.description,
            total: score.total,
            color: colors.map { rgb($0.primary) },
            secondColor: colors?.secondary.map { rgb($0) }
        )
    }

    private static func rgb(_ color: KitColor) -> MatchActivityAttributes.RGB {
        let (red, green, blue) = color.rgb
        return MatchActivityAttributes.RGB(red: red, green: green, blue: blue)
    }
}
