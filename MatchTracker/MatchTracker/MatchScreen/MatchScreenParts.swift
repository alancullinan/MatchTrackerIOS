import MatchCore
import SwiftUI

/// The period name in gold and the big clock. During a break the clock shows
/// how long the last period ran ("31 min"), never 00:00.
struct ClockView: View {
    let match: Match

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                if match.clock.period.isPlaying {
                    Circle()
                        .fill(match.clock.isRunning ? MatchTheme.live : MatchTheme.muted)
                        .frame(width: 8, height: 8)
                }
                Text(match.clock.period.displayName.uppercased())
                    .font(MatchTheme.display(18, .bold))
                    .tracking(2.5)
                    .foregroundStyle(MatchTheme.gold)
            }

            TimelineView(.periodic(from: match.clock.runningSince ?? .now, by: 1)) { timeline in
                Text(clockText(at: timeline.date))
                    .font(MatchTheme.display(76))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Text(note)
                .font(.footnote)
                .foregroundStyle(MatchTheme.muted)
                .frame(minHeight: 18)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func clockText(at now: Date) -> String {
        let period = match.clock.period
        if period.isPlaying || period == .notStarted {
            return MatchClock.text(seconds: match.clock.elapsed(at: now))
        }
        guard let lastEnd = match.lastPeriodEnd else { return "–" }
        return "\(lastEnd.time / 60) min"
    }

    private var note: String {
        switch match.clock.period {
        case .notStarted: "Tap Start at the throw-in"
        case .halfTime, .extraTimeHalfTime: "Break"
        case .fullTime: "Match over, unless it goes to extra time"
        case .fullTimeAfterExtraTime: "Match over after extra time"
        case .firstHalf, .secondHalf, .extraTimeFirstHalf, .extraTimeSecondHalf:
            match.clock.isRunning ? "" : "Paused"
        }
    }
}

/// One team: name and colours on top, then goal flag · score · point flag.
struct TeamCard: View {
    let team: Team
    let score: Score
    let flagsEnabled: Bool
    let onScore: (ShotOutcome) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if let colors = team.colors {
                    TeamColorBadge(colors: colors, size: 26)
                }
                Text(EventText.teamName(team).uppercased())
                    .font(MatchTheme.display(24, .bold))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(alignment: .center) {
                FlagButton(outcome: .goal, teamName: team.name, enabled: flagsEnabled) { onScore(.goal) }
                Spacer(minLength: 8)
                scoreText
                Spacer(minLength: 8)
                FlagButton(outcome: .point, teamName: team.name, enabled: flagsEnabled) { onScore(.point) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(team.colors.map { $0.primary.color.opacity(0.28) }), in: .rect(cornerRadius: 26))
    }

    private var scoreText: some View {
        VStack(spacing: 4) {
            (Text("\(score.goals)")
                + Text("-").foregroundStyle(MatchTheme.gold)
                + Text(score.points < 10 ? "0\(score.points)" : "\(score.points)"))
                .font(MatchTheme.display(64))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("(\(score.total))")
                .font(MatchTheme.display(22))
                .monospacedDigit()
                .foregroundStyle(MatchTheme.muted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score.goals) goals, \(score.points) points, \(score.total) in total")
    }
}

/// A round umpire's-flag button: green for a goal, white for a point.
struct FlagButton: View {
    let outcome: ShotOutcome
    let teamName: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                FlagIcon(fill: fill)
                    .frame(width: 34, height: 34)
                    .frame(width: 64, height: 64)
                    .background(MatchTheme.flagDisc, in: .circle)
                    .overlay(Circle().strokeBorder(fill, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 6)
                Text(outcome.displayName.uppercased())
                    .font(MatchTheme.display(14))
                    .tracking(1)
                    .foregroundStyle(MatchTheme.muted)
            }
        }
        .buttonStyle(FlagPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel("\(outcome.displayName) for \(teamName)")
    }

    private var fill: Color { outcome == .goal ? MatchTheme.goal : MatchTheme.point }
}

private struct FlagPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The latest thing that happened, with Undo for a few seconds after each entry.
struct LastEventCard: View {
    /// A filled flag for a score, an outline for a miss.
    enum Flag { case filled(Color), outline }

    let title: String
    let detail: String
    let flag: Flag?
    let showsUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            switch flag {
            case .filled(let color): FlagIcon(fill: color, pole: .primary).frame(width: 30, height: 30)
            case .outline: FlagIcon(fill: nil, pole: .primary).frame(width: 30, height: 30)
            case nil: EmptyView()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(MatchTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if showsUndo {
                Button("Undo", action: onUndo)
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .overlay {
            if showsUndo {
                RoundedRectangle(cornerRadius: 22).strokeBorder(MatchTheme.gold, lineWidth: 2)
            }
        }
        .animation(.default, value: showsUndo)
    }
}
