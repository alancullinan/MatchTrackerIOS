import MatchCore
import SwiftUI

/// The details of a shot that has just been counted: point or two-pointer (or
/// which kind of miss), how it was taken, and who took it. Nothing changes
/// until Done; dismissing keeps the shot as it was.
struct ScorerSheet: View {
    let session: MatchSession
    let eventID: EventID

    @Environment(\.dismiss) private var dismiss
    @State private var outcome: ShotOutcome = .point
    @State private var type: ShotType = .fromPlay
    @State private var player: PlayerID?
    @State private var note = NoteDraft()
    @State private var loaded = false

    private var match: Match { session.match }

    var body: some View {
        if case .shot(let side, _, let recorded, _) = match.event(eventID)?.kind {
            content(side: side, recorded: recorded)
                .onAppear(perform: load)
        } else {
            // Deleted elsewhere (e.g. undone) while the sheet was opening.
            EventGoneView()
        }
    }

    private func content(side: TeamSide, recorded: ShotOutcome) -> some View {
        let team = match[side]
        let outcomes = recorded.alternatives(in: match.matchType)
        return EventSheetLayout(
            title: EventText.teamName(team),
            undoTitle: "Undo \(recorded.displayName.lowercased())",
            onUndo: {
                session.deleteEvent(eventID)
                dismiss()
            },
            onDone: {
                session.updateShot(eventID, outcome: outcome, type: type, player: player,
                                   note: note.text(keeping: match.event(eventID)?.note))
                dismiss()
            }
        ) {
            if outcomes.count > 1 {
                Picker("Outcome", selection: $outcome) {
                    ForEach(outcomes, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
            }

            ChoiceChips(options: ShotType.options(for: match.matchType), selection: $type) { Text($0.displayName) }

            SheetLabel(recorded.scores ? "Scorer" : "Player")
            TeamSheetPicker(team: team, selection: $player)
            NoteField(draft: $note)

            if recorded.scores {
                Button("Stop asking for \(EventText.teamName(team)) scorers") {
                    session.setAsksForScorers(false, for: side)
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    /// Starts from the shot as recorded, so reopening it with Details shows its details.
    private func load() {
        guard !loaded, let event = match.event(eventID), case .shot(_, let player, let outcome, let type) = event.kind else { return }
        loaded = true
        self.outcome = outcome
        self.type = type
        self.player = player
        note.load(event.note)
    }
}

/// A team sheet laid out like the pitch, forwards at the top down to the
/// goalkeeper, with subs 16-30 below. Tapping a player highlights them; tapping
/// them again clears it. A `marked` player (e.g. the one coming off, while the
/// one coming on is picked) is outlined.
struct TeamSheetPicker: View {
    let team: Team
    @Binding var selection: PlayerID?
    var marked: PlayerID?

    /// Jersey numbers by line, from full forwards to goalkeeper.
    static let lines: [[Int]] = [[13, 14, 15], [10, 11, 12], [8, 9], [5, 6, 7], [2, 3, 4], [1]]
    static let subs = Array(16...Team.rosterSize)

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                ForEach(Self.lines, id: \.self) { line in
                    HStack(spacing: 8) {
                        ForEach(line, id: \.self) { number in
                            playerButton(number, minHeight: 62)
                                .frame(maxWidth: 110)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(10)
            .background(MatchTheme.goal.opacity(0.08), in: .rect(cornerRadius: 18))

            Text("Subs")
                .font(.footnote.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(Self.subs, id: \.self) { number in
                    playerButton(number, minHeight: 48)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func playerButton(_ number: Int, minHeight: CGFloat) -> some View {
        if let player = team.player(jersey: number) {
            let selected = player.id == selection
            let name = EventText.nameLines(player)
            Button {
                selection = selected ? nil : player.id
            } label: {
                VStack(spacing: 1) {
                    Text("\(number)")
                        .font(MatchTheme.display(20, .bold))
                        .monospacedDigit()
                    if let first = name.first {
                        Text(first).font(.caption)
                    }
                    if let surname = name.surname {
                        Text(surname).font(.caption.weight(.bold))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .foregroundStyle(selected ? MatchTheme.goldInk : .primary)
                .background(selected ? AnyShapeStyle(MatchTheme.gold) : AnyShapeStyle(.background.secondary),
                            in: .rect(cornerRadius: 12))
                .overlay {
                    if player.id == marked {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(MatchTheme.gold, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(EventText.playerName(player))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

/// Lays children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let added = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if added > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#if DEBUG
#Preview("Scorer sheet") {
    let session = MatchSession.preview(.secondHalf)
    let point = session.match.events.last!.id
    return ScorerSheet(session: session, eventID: point)
}
#endif
