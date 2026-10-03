import ActivityKit
import SwiftUI
import WidgetKit

/// The live match on the Lock Screen and in the Dynamic Island: both scores,
/// the period and the clock, which the system counts up by itself while play
/// is running, so it stays right without the app.
struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Palette.pitch)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TeamColumn(team: state.team1, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamColumn(team: state.team2, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.periodName.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.gold)
                        ClockText(state: state)
                            .font(.title3.weight(.semibold))
                            .frame(width: 72)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let lastEvent = state.lastEvent {
                        Text(lastEvent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Badge(team: state.team1, size: 10)
                    Text(state.team1.score).monospacedDigit()
                }
            } compactTrailing: {
                HStack(spacing: 4) {
                    Text(state.team2.score).monospacedDigit()
                    Badge(team: state.team2, size: 10)
                }
            } minimal: {
                Text("\(state.team1.total)-\(state.team2.total)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }
            .keylineTint(Palette.gold)
        }
    }
}

private enum Palette {
    static let pitch = Color(red: 0.06, green: 0.19, blue: 0.11)
    static let gold = Color(red: 1, green: 0.84, blue: 0.04)
}

private struct LockScreenView: View {
    let attributes: MatchActivityAttributes
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(attributes.competition.isEmpty ? "MatchTracker" : attributes.competition)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer()
                Text(state.periodName.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.gold)
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TeamRow(team: state.team1)
                    TeamRow(team: state.team2)
                }
                .frame(maxWidth: .infinity)
                // A timer text takes all the width it is offered, so it gets a fixed width.
                ClockText(state: state)
                    .font(.system(size: 34, weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(width: 112, alignment: .trailing)
            }
            if let lastEvent = state.lastEvent {
                Text(lastEvent)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

private struct TeamRow: View {
    let team: MatchActivityAttributes.TeamLine

    var body: some View {
        HStack(spacing: 8) {
            Badge(team: team, size: 14)
            Text(team.name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(team.score)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .fixedSize()
            Text("(\(team.total))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .monospacedDigit()
                .fixedSize()
        }
    }
}

private struct TeamColumn: View {
    let team: MatchActivityAttributes.TeamLine
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 4) {
                if alignment == .leading { Badge(team: team, size: 10) }
                Text(team.name).font(.caption).lineLimit(1)
                if alignment == .trailing { Badge(team: team, size: 10) }
            }
            Text(team.score)
                .font(.title2.weight(.bold))
                .monospacedDigit()
        }
        // Clear of the island's rounded corners.
        .padding(.horizontal, 6)
    }
}

/// The running clock counts up by itself from when it read 0:00; a stopped
/// one shows its text ("23:41" paused, "31 min" in a break).
private struct ClockText: View {
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        if let start = state.clockStartedAt {
            Text(timerInterval: start...start.addingTimeInterval(4 * 3600), countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text(state.stoppedClock)
                .monospacedDigit()
        }
    }
}

/// A team's colours as a small round badge, split for two colours.
private struct Badge: View {
    let team: MatchActivityAttributes.TeamLine
    let size: CGFloat

    var body: some View {
        if let main = team.color {
            HStack(spacing: 0) {
                color(main)
                color(team.secondColor ?? main)
            }
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
        }
    }

    private func color(_ rgb: MatchActivityAttributes.RGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

#if DEBUG
private extension MatchActivityAttributes {
    static let preview = MatchActivityAttributes(matchID: UUID(), competition: "U16 A Championship Final")
}

private extension MatchActivityAttributes.ContentState {
    static let running = MatchActivityAttributes.ContentState(
        team1: .init(name: "Commercials", score: "1-05", total: 8,
                     color: .init(red: 0.12, green: 0.31, blue: 0.75), secondColor: .init(red: 1, green: 1, blue: 1)),
        team2: .init(name: "Brian Borus", score: "0-07", total: 7,
                     color: .init(red: 0.82, green: 0.13, blue: 0.18), secondColor: nil),
        periodName: "2nd Half",
        clockStartedAt: Date.now.addingTimeInterval(-1122),
        stoppedClock: "",
        lastEvent: "Point · Commercials · No. 11 Seán Ryan"
    )

    static let halfTime: Self = {
        var state = running
        state.periodName = "Half Time"
        state.clockStartedAt = nil
        state.stoppedClock = "31 min"
        state.lastEvent = "End of 1st Half"
        return state
    }()
}

#Preview("Lock Screen", as: .content, using: MatchActivityAttributes.preview) {
    MatchLiveActivity()
} contentStates: {
    MatchActivityAttributes.ContentState.running
    MatchActivityAttributes.ContentState.halfTime
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: MatchActivityAttributes.preview) {
    MatchLiveActivity()
} contentStates: {
    MatchActivityAttributes.ContentState.running
}

#Preview("Compact", as: .dynamicIsland(.compact), using: MatchActivityAttributes.preview) {
    MatchLiveActivity()
} contentStates: {
    MatchActivityAttributes.ContentState.running
}
#endif
