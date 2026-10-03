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

/// One team on plain glass: colour badge · name · total points on top, the
/// score in the middle, More below, and the goal and point flags either side,
/// centred on the whole card.
struct TeamCard: View {
    let team: Team
    let score: Score
    let flagsEnabled: Bool
    let onScore: (ShotOutcome) -> Void
    let onMore: () -> Void

    /// Room kept clear for the flags: a 62-point flag, 16 points in from the
    /// card's edge, less the card's padding, plus a gap.
    private static let flagClearance: CGFloat = 70

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Text(EventText.teamName(team))
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 84)
                HStack {
                    if let colors = team.colors {
                        TeamColorBadge(colors: colors, size: 24)
                    }
                    Spacer(minLength: 0)
                    totalPill
                }
            }
            .padding(.top, 2)

            scoreText
                .padding(.horizontal, Self.flagClearance)

            Button(action: onMore) {
                Label("More", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 4)
                    .frame(minHeight: 36)
            }
            .buttonStyle(.glass)
            .padding(.top, 4)
            .accessibilityLabel("More for \(EventText.teamName(team))")
        }
        .padding(14)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            FlagButton(outcome: .goal, teamName: EventText.teamName(team), enabled: flagsEnabled) { onScore(.goal) }
                .padding(.leading, 16)
        }
        .overlay(alignment: .trailing) {
            FlagButton(outcome: .point, teamName: EventText.teamName(team), enabled: flagsEnabled) { onScore(.point) }
                .padding(.trailing, 16)
        }
        .matchGlass(in: .rect(cornerRadius: 32))
    }

    private var totalPill: some View {
        Text(score.total == 1 ? "1 pt" : "\(score.total) pts")
            .font(.system(size: 17, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.9))
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(.black.opacity(0.28), in: .capsule)
            .fixedSize()
            .accessibilityLabel("\(score.total) in total")
    }

    /// "1-05", with a short gold hyphen.
    private var scoreText: some View {
        let points = score.points < 10 ? "0\(score.points)" : "\(score.points)"
        // Thin spaces give the hyphen a little room against the tight tracking.
        return Text("\(score.goals)\(Text("\u{2009}-\u{2009}").foregroundStyle(MatchTheme.gold))\(points)")
            .font(.system(size: 64, weight: .bold))
            .monospacedDigit()
            .tracking(-1.9)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel("\(score.goals) goals, \(score.points) points")
    }
}

/// A round flag button: green for a goal, white for a point.
struct FlagButton: View {
    let outcome: ShotOutcome
    let teamName: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WavingFlag()
                .fill(color)
                .frame(width: 36, height: 36)
                .frame(width: 62, height: 62)
                .background(color.opacity(outcome == .goal ? 0.22 : 0.18), in: .circle)
                .overlay(Circle().strokeBorder(color.opacity(outcome == .goal ? 0.6 : 0.55), lineWidth: 1))
                .contentShape(.circle)
        }
        .buttonStyle(FlagPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel("\(outcome.displayName) for \(teamName)")
    }

    private var color: Color { outcome == .goal ? MatchTheme.goal : MatchTheme.point }
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
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
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
        .padding(.leading, showsUndo ? 16 : 22)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
        .frame(minHeight: 76)
        .matchGlass(in: .rect(cornerRadius: 38))
        .overlay {
            if showsUndo {
                RoundedRectangle(cornerRadius: 38).strokeBorder(MatchTheme.gold, lineWidth: 2)
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
                // First, and always available: names and numbers are often
                // added before throw-in, while the event rows are disabled.
                Section {
                    Button {
                        dismiss()
                        onTeamSheet()
                    } label: {
                        LabeledContent {
                            Text("Add and name players")
                        } label: {
                            Label { Text("Team Sheet") } icon: {
                                Image(systemName: "person.3").foregroundStyle(.primary).frame(width: 26, height: 26)
                            }
                        }
                    }
                    .tint(.primary)
                }

                Section {
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
                } footer: {
                    if !canRecord {
                        Text("Events can be recorded while the ball is in play.")
                    }
                }
            }
            .navigationTitle(teamName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
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
