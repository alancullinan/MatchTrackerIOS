import MatchCore
import SwiftUI

/// One match in the list: both teams with their scores, then the period,
/// competition and date.
struct MatchRow: View {
    let stored: StoredMatch

    var body: some View {
        // Team names are stored columns, so even a match that can't be read
        // still shows which match it is.
        let match = try? stored.match()
        // If either team has colours, both names leave room for a badge so they line up.
        let showsBadges = match?.team1.colors != nil || match?.team2.colors != nil

        VStack(alignment: .leading, spacing: 6) {
            team(stored.team1Name, colors: match?.team1.colors, showsBadge: showsBadges, score: match?.score(.team1))
            team(stored.team2Name, colors: match?.team2.colors, showsBadge: showsBadges, score: match?.score(.team2))

            if let match {
                details(for: match)
            } else {
                Label("This match can't be read", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func team(_ name: String, colors: TeamColors?, showsBadge: Bool, score: Score?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if showsBadge {
                Group {
                    if let colors {
                        TeamColorBadge(colors: colors)
                    } else {
                        Color.clear.frame(width: 14, height: 14)
                    }
                }
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            }
            Text(name.isEmpty ? "Unnamed team" : name)
                .font(.headline)
                .lineLimit(2)
            Spacer(minLength: 12)
            if let score {
                Text(score.description)
                    .font(.title3.bold().monospacedDigit())
                    .accessibilityLabel("\(score.goals) goals, \(score.points) points")
            }
        }
    }

    private func details(for match: Match) -> some View {
        HStack(spacing: 6) {
            if match.clock.period.isPlaying {
                Text(match.clock.isRunning ? "LIVE" : "PAUSED")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(match.clock.isRunning ? Color.red : Color.gray, in: .capsule)
            }
            Text(detailText(for: match))
                .lineLimit(1)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func detailText(for match: Match) -> String {
        [match.clock.period.displayName, match.competition, match.date.formatted(date: .abbreviated, time: .omitted)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
