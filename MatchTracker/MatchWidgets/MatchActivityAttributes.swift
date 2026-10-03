import ActivityKit
import Foundation

/// A live match on the Lock Screen and in the Dynamic Island. Shared by the
/// app (which starts and updates it) and the widget extension (which draws
/// it), so it holds plain values only: the widget doesn't know about MatchCore.
/// The app builds it from a match in `MatchActivityContent`.
///
/// Its `Codable` shape is how the app hands it to the system: change it only
/// additively while an activity could be running, like stored data.
nonisolated struct MatchActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var team1: TeamLine
        var team2: TeamLine
        /// "2nd Half", "Half Time", "Full Time (AET)".
        var periodName: String
        /// When the running clock read 0:00, so the system can count up without
        /// the app (a wall-clock time, like the match clock). `nil` while stopped.
        var clockStartedAt: Date?
        /// What the clock shows while stopped: "23:41" when paused, "31 min" in a break.
        var stoppedClock: String
        /// The last thing recorded, e.g. "Point · Na Fianna · No. 11 Seán Ryan".
        var lastEvent: String?
    }

    struct TeamLine: Codable, Hashable {
        var name: String
        /// "1-05".
        var score: String
        var total: Int
        var color: RGB?
        var secondColor: RGB?
    }

    /// A kit colour as red, green and blue from 0 to 1.
    struct RGB: Codable, Hashable {
        var red: Double
        var green: Double
        var blue: Double
    }

    /// The match this is for, so the app can find and end it.
    var matchID: UUID
    var competition: String
}
