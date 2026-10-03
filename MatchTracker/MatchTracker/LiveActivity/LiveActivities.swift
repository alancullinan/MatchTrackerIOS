import ActivityKit
import Foundation
import MatchCore
import OSLog

/// Starts, updates and ends the Live Activity for the match being tracked:
/// the score, period and running clock on the Lock Screen and in the Dynamic
/// Island. One match at a time; the system counts the clock up by itself
/// from `clockStartedAt`, so updates are only needed when something changes.
enum LiveActivities {
    private static let log = Logger(subsystem: "com.alancullinan.MatchTracker", category: "LiveActivity")

    /// Brings the Live Activity in line with `match`: starts one once the
    /// match is under way, updates it, and ends it at full time (the final
    /// score stays on the Lock Screen for a while) or straight away if the
    /// match goes back to not started. Safe to call after every change.
    static func update(for match: Match) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.notice("Live Activities are turned off")
            return
        }
        let id = match.id.uuid
        let content = ActivityContent(state: MatchActivityContent.state(for: match), staleDate: nil)
        let activities = Activity<MatchActivityAttributes>.activities
        let mine = activities.filter { $0.attributes.matchID == id }

        guard MatchActivityContent.isLive(match) else {
            let policy: ActivityUIDismissalPolicy = match.clock.period == .notStarted ? .immediate : .default
            for activity in mine {
                Task { await activity.end(content, dismissalPolicy: policy) }
            }
            return
        }

        // Only the match being tracked shows.
        for other in activities where other.attributes.matchID != id {
            Task { await other.end(nil, dismissalPolicy: .immediate) }
        }
        if let activity = mine.first {
            Task { await activity.update(content) }
        } else {
            do {
                _ = try Activity.request(attributes: MatchActivityContent.attributes(for: match), content: content)
                log.notice("Started a Live Activity")
            } catch {
                // Not worth interrupting a match for: the app works the same without it.
                log.error("Couldn't start a Live Activity: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Ends a deleted match's Live Activity, if it has one.
    static func end(matchID: MatchID) {
        for activity in Activity<MatchActivityAttributes>.activities where activity.attributes.matchID == matchID.uuid {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
