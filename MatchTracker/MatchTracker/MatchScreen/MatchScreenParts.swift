import MatchCore
import SwiftUI

/// The clock capsule: the period name in gold and the big clock, with the
/// clock button beside them and a hint underneath. During a break the clock
/// shows how long the last period ran ("31 min"), never 00:00.
struct ClockView<Control: View>: View {
    let match: Match
    let hint: String
    /// Opens the clock editor; the caller decides when that applies.
    let onAdjust: () -> Void
    @ViewBuilder let control: Control

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(MatchTheme.gold)
                    TimelineView(.periodic(from: match.clock.runningSince ?? .now, by: 1)) { timeline in
                        Text(clockText(at: timeline.date))
                            .font(.system(size: 52, weight: .semibold))
                            .monospacedDigit()
                            .tracking(-1)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .contentShape(.rect)
                .onTapGesture(perform: onAdjust)
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: "Adjust clock", onAdjust)

                control
            }
            .padding(.leading, 26)
            .padding([.vertical, .trailing], 6)
            .matchGlass(in: .capsule)

            Text(hint)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MatchTheme.muted)
                .multilineTextAlignment(.center)
                .frame(minHeight: 16)
        }
        .frame(maxWidth: .infinity)
    }

    /// "1ST HALF", or "1ST HALF · PAUSED" while play is stopped.
    private var label: String {
        let period = match.clock.period
        let name = period.displayName.uppercased()
        return period.isPlaying && !match.clock.isRunning ? "\(name) · PAUSED" : name
    }

    private func clockText(at now: Date) -> String {
        let period = match.clock.period
        if period.isPlaying || period == .notStarted {
            return MatchClock.text(seconds: match.clock.elapsed(at: now))
        }
        guard let lastEnd = match.lastPeriodEnd else { return "–" }
        return "\(lastEnd.time / 60) min"
    }
}

/// The clock button's face: a gold disc with a dark glyph inside a progress
/// ring that fills while the button is held.
struct ClockButtonFace: View {
    let systemImage: String
    /// How far the ring is filled, 0 to 1.
    var progress: Double = 0
    var isPressed = false

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MatchTheme.goldInk)
                .frame(width: 62, height: 62)
                .background(MatchTheme.gold, in: .circle)
                .shadow(color: MatchTheme.gold.opacity(0.35), radius: 9, y: 6)
                .scaleEffect(isPressed ? 0.92 : 1)
        }
        .padding(2)
        .frame(width: 76, height: 76)
    }
}

/// One team: name and colours on top, then goal flag · score · point flag.
struct TeamCard: View {
    let team: Team
    let score: Score
    let flagsEnabled: Bool
    let onScore: (ShotOutcome) -> Void
    let onMore: () -> Void

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

            Button("More", systemImage: "plus", action: onMore)
                .font(.callout.weight(.semibold))
                .buttonStyle(.glass)
                .controlSize(.large)
                .accessibilityLabel("More for \(team.name)")
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

/// An event's icon: a flag for a shot (filled for a score, outlined for a
/// miss), the card for a foul with one, and a symbol for anything else.
struct EventIcon: View {
    let event: MatchEvent

    init(_ event: MatchEvent) { self.event = event }

    var body: some View {
        switch event.kind {
        case .shot(_, _, let outcome, _):
            switch outcome {
            case .goal: flag(MatchTheme.goal)
            case .point: flag(MatchTheme.point)
            case .twoPointer: flag(MatchTheme.twoPointer)
            case .wide, .saved, .droppedShort, .offPost: flag(nil)
            }
        case .foul(_, _, _, let card?), .card(_, _, let card):
            CardSwatch(card: card).frame(width: 20, height: 27).frame(width: 30, height: 30)
        case .foul: symbol("hand.raised.fill")
        case .kickout: symbol("arrow.up.forward")
        case .substitution: symbol("arrow.left.arrow.right")
        case .note: symbol("text.bubble")
        case .periodEnd: symbol("flag.checkered")
        }
    }

    private func flag(_ fill: Color?) -> some View {
        FlagIcon(fill: fill, pole: .primary).frame(width: 30, height: 30)
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.title3).frame(width: 30, height: 30).accessibilityHidden(true)
    }
}

/// The latest thing that happened, with Undo for a few seconds after each entry.
struct LastEventCard: View {
    let title: String
    let detail: String
    let icon: EventIcon?
    let showsUndo: Bool
    let onUndo: () -> Void
    /// Reopens the event's details sheet; `nil` when it has none.
    var onDetails: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            icon
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
                HStack(spacing: 6) {
                    if let onDetails {
                        Button("Details", action: onDetails)
                            .buttonStyle(.glass)
                            .controlSize(.large)
                            .fixedSize()
                    }
                    Button("Undo", action: onUndo)
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .fixedSize()
                }
                // The buttons keep their size; a long title wraps instead.
                .layoutPriority(1)
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

/// Everything else that can be recorded for a team: a miss, a foul (with any
/// card), a kickout, a substitution or a note. Each is recorded at the tap, then its
/// sheet opens for the details. Also the team sheet, which can be edited any time.
struct MoreSheet: View {
    let teamName: String
    let side: TeamSide
    let canRecord: Bool
    let onRecord: (MatchSession.Action) -> Void
    var onTeamSheet: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("Miss", detail: "Wide, saved, short or off the post", action: .miss(side)) {
                    FlagIcon(fill: nil, pole: .primary)
                }
                row("Foul", detail: "A free or penalty, and any card", action: .foul(side)) {
                    Image(systemName: "hand.raised.fill")
                }
                row("Kickout", detail: "Their own kickout, won or lost", action: .kickout(side)) {
                    Image(systemName: "arrow.up.forward")
                }
                row("Substitution", detail: "Who came off and who came on", action: .substitution(side)) {
                    Image(systemName: "arrow.left.arrow.right")
                }
                row("Note", detail: "Anything worth remembering", action: .note(side)) {
                    Image(systemName: "text.bubble")
                }

                Section {
                    Button {
                        dismiss()
                        onTeamSheet()
                    } label: {
                        LabeledContent {
                            Text("Names and numbers")
                        } label: {
                            Label { Text("Team Sheet") } icon: {
                                Image(systemName: "person.3").foregroundStyle(.primary).frame(width: 26, height: 26)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle(teamName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !canRecord {
                    Text("Events can be recorded while the ball is in play.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, detail: String, action: MatchSession.Action,
                     @ViewBuilder icon: () -> some View) -> some View {
        Button { record(action) } label: {
            LabeledContent {
                Text(detail)
            } label: {
                Label { Text(title) } icon: { icon().foregroundStyle(.primary).frame(width: 26, height: 26) }
            }
        }
        .tint(.primary)
        .disabled(!canRecord)
    }

    private func record(_ action: MatchSession.Action) {
        dismiss()
        onRecord(action)
    }
}
