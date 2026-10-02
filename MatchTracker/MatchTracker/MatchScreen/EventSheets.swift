import MatchCore
import SwiftUI

/// The details sheet for an event that has just been recorded (or reopened
/// with Details): the scorer sheet for a shot, or the foul, kickout,
/// substitution or note sheet. Each records nothing new until Done; dismissing
/// keeps the event as it was. A note is the exception: its text is saved
/// however the sheet closes, since the text is the note.
struct EventDetailsSheet: View {
    let session: MatchSession
    let eventID: EventID

    var body: some View {
        switch session.match.event(eventID)?.kind {
        case .foul?: FoulSheet(session: session, eventID: eventID)
        case .kickout?: KickoutSheet(session: session, eventID: eventID)
        case .substitution?: SubstitutionSheet(session: session, eventID: eventID)
        case .note?: NoteSheet(session: session, eventID: eventID)
        case .periodEnd?, .card?: TimeOnlySheet(session: session, eventID: eventID)
        case .shot?, nil: ScorerSheet(session: session, eventID: eventID)
        }
    }
}

/// A foul conceded by the team: a free or a penalty, any card shown, and who fouled.
struct FoulSheet: View {
    let session: MatchSession
    let eventID: EventID

    @Environment(\.dismiss) private var dismiss
    @State private var outcome: FoulOutcome = .free
    @State private var card: CardType?
    @State private var player: PlayerID?
    @State private var note = NoteDraft()

    var body: some View {
        if case .foul(let side, let recordedPlayer, let recordedOutcome, let recordedCard) = session.match.event(eventID)?.kind {
            let team = session.match[side]
            EventSheetLayout(session: session, eventID: eventID, title: EventText.teamName(team), undoTitle: "Undo foul",
                             onUndo: { session.deleteEvent(eventID); dismiss() },
                             onDone: {
                                 session.updateFoul(eventID, outcome: outcome, card: card, player: player,
                                                    note: note.text(keeping: session.match.event(eventID)?.note))
                                 dismiss()
                             }) {
                Picker("Outcome", selection: $outcome) {
                    ForEach(FoulOutcome.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                SheetLabel("Card")
                ChoiceChips(options: cardOptions(keeping: recordedCard), selection: $card) { card in
                    HStack(spacing: 6) {
                        if let card { CardSwatch(card: card).frame(width: 14, height: 19) }
                        Text(card?.displayName ?? "No card")
                    }
                }

                SheetLabel("Fouled by")
                TeamSheetPicker(team: team, selection: $player)
                NoteField(draft: $note)
            }
            .onAppear {
                outcome = recordedOutcome
                card = recordedCard
                player = recordedPlayer
                note.load(session.match.event(eventID)?.note)
            }
        } else {
            EventGoneView()
        }
    }
}

extension FoulSheet {
    /// No card, then the cards used in this code, plus the foul's own card if
    /// the code doesn't use it (e.g. an older record), so it isn't lost.
    private func cardOptions(keeping recorded: CardType?) -> [CardType?] {
        var cards = CardType.options(for: session.match.matchType)
        if let recorded, !cards.contains(recorded) { cards.append(recorded) }
        return [nil] + cards
    }
}

/// The team's own kickout: won or lost, and who won it.
struct KickoutSheet: View {
    let session: MatchSession
    let eventID: EventID

    @Environment(\.dismiss) private var dismiss
    @State private var won = true
    @State private var player: PlayerID?
    @State private var note = NoteDraft()

    var body: some View {
        if case .kickout(let side, let recordedPlayer, let recordedWon) = session.match.event(eventID)?.kind {
            let team = session.match[side]
            EventSheetLayout(session: session, eventID: eventID, title: EventText.teamName(team), undoTitle: "Undo kickout",
                             onUndo: { session.deleteEvent(eventID); dismiss() },
                             onDone: {
                                 // Only a kickout that was won has one of this team's players winning it.
                                 session.updateKickout(eventID, won: won, player: won ? player : nil,
                                                       note: note.text(keeping: session.match.event(eventID)?.note))
                                 dismiss()
                             }) {
                Picker("Kickout", selection: $won) {
                    Text("Won").tag(true)
                    Text("Lost").tag(false)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)

                if won {
                    SheetLabel("Won by")
                    TeamSheetPicker(team: team, selection: $player)
                }
                NoteField(draft: $note)
            }
            .onAppear {
                won = recordedWon
                player = recordedPlayer
                note.load(session.match.event(eventID)?.note)
            }
        } else {
            EventGoneView()
        }
    }
}

/// Who came off and who came on, picked on one team sheet: pick the player
/// coming off, and the sheet moves on to the player coming on.
struct SubstitutionSheet: View {
    let session: MatchSession
    let eventID: EventID

    private enum Slot { case off, on }

    @Environment(\.dismiss) private var dismiss
    @State private var off: PlayerID?
    @State private var on: PlayerID?
    @State private var picking = Slot.off
    @State private var note = NoteDraft()

    var body: some View {
        if case .substitution(let side, let recordedOff, let recordedOn) = session.match.event(eventID)?.kind {
            let team = session.match[side]
            EventSheetLayout(session: session, eventID: eventID, title: EventText.teamName(team), undoTitle: "Undo substitution",
                             onUndo: { session.deleteEvent(eventID); dismiss() },
                             onDone: {
                                 session.updateSubstitution(eventID, off: off, on: on,
                                                            note: note.text(keeping: session.match.event(eventID)?.note))
                                 dismiss()
                             }) {
                HStack(spacing: 10) {
                    slotButton(.off, team: team)
                    slotButton(.on, team: team)
                }
                TeamSheetPicker(team: team, selection: pickedBinding, marked: picking == .off ? on : off)
                NoteField(draft: $note)
            }
            .onAppear {
                off = recordedOff
                on = recordedOn
                picking = recordedOff != nil && recordedOn == nil ? .on : .off
                note.load(session.match.event(eventID)?.note)
            }
        } else {
            EventGoneView()
        }
    }

    /// The player for the slot being picked. Picking the player already in the
    /// other slot moves them across; picking the player coming off moves on.
    private var pickedBinding: Binding<PlayerID?> {
        Binding {
            picking == .off ? off : on
        } set: { player in
            switch picking {
            case .off:
                if player != nil, player == on { on = nil }
                off = player
                if player != nil { picking = .on }
            case .on:
                if player != nil, player == off { off = nil }
                on = player
            }
        }
    }

    private func slotButton(_ slot: Slot, team: Team) -> some View {
        let player = (slot == .off ? off : on).flatMap(team.player)
        let selected = picking == slot
        return Button { picking = slot } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(slot == .off ? "Off" : "On", systemImage: slot == .off ? "arrow.down" : "arrow.up")
                    .font(.footnote.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(player.map(EventText.playerName) ?? "Tap a player")
                    .font(.headline)
                    .foregroundStyle(player == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(.fill.tertiary, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? MatchTheme.gold : .clear, lineWidth: 2.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(slot == .off ? "Coming off" : "Coming on"): \(player.map(EventText.playerName) ?? "none")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A note's text. It is saved however the sheet closes; a note left blank is deleted.
struct NoteSheet: View {
    let session: MatchSession
    let eventID: EventID

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var cancelled = false
    @State private var when = EventTimeDraft()
    @FocusState private var focused: Bool

    var body: some View {
        if case .note(let side) = session.match.event(eventID)?.kind {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("What happened?", text: $text, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($focused)
                            .padding(12)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                        EventTimeField(match: session.match, eventID: eventID, draft: $when)
                    }
                    .padding(16)
                }
                    .navigationTitle(side.map { "Note · \(EventText.teamName(session.match[$0]))" } ?? "Match note")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", role: .cancel) {
                                cancelled = true
                                session.deleteEvent(eventID)
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", role: .confirm) { dismiss() }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .onAppear {
                text = session.match.event(eventID)?.note ?? ""
                when.load(session.match.event(eventID))
                focused = true
            }
            .onDisappear {
                guard !cancelled else { return }
                // A blank note is deleted, and then there is no time to save.
                if session.saveNote(eventID, text: text) { when.save(eventID, in: session) }
            }
        } else {
            EventGoneView()
        }
    }
}

// MARK: - Shared parts

/// The frame every details sheet shares: the title, Undo on the left and
/// Done on the right, the content scrolling below, and the event's time at
/// the bottom, collapsed until it needs changing. Done saves the time too.
struct EventSheetLayout<Content: View>: View {
    let session: MatchSession
    let eventID: EventID
    let title: String
    /// `nil` for an event that can't be removed (a period end): the sheet offers Cancel instead.
    let undoTitle: String?
    var onUndo: () -> Void = {}
    let onDone: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
    @State private var when = EventTimeDraft()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                    EventTimeField(match: session.match, eventID: eventID, draft: $when)
                }
                .padding(16)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let undoTitle {
                        Button(undoTitle, role: .destructive, action: onUndo)
                            .tint(.red)
                    } else {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        when.save(eventID, in: session)
                        onDone()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { when.load(session.match.event(eventID)) }
    }
}

/// An event's period and time being edited on a sheet.
struct EventTimeDraft {
    var period: MatchPeriod = .firstHalf
    var minutes = 0
    var seconds = 0
    var isShown = false
    private var original: (period: MatchPeriod, time: Int)?

    var time: Int { minutes * 60 + seconds }

    /// Starts from the event as recorded, once. Open from the start for an
    /// event whose time is all there is to edit.
    mutating func load(_ event: MatchEvent?) {
        guard original == nil, let event else { return }
        original = (event.period, event.time)
        switch event.kind {
        case .periodEnd, .card: isShown = true
        default: break
        }
        period = event.period
        minutes = event.time / 60
        seconds = event.time % 60
    }

    /// Saves the period and time if they were changed, brought within what
    /// the period allows (e.g. not after it ended).
    func save(_ id: EventID, in session: MatchSession) {
        guard let original, period != original.period || time != original.time,
              let limits = session.match.timeLimits(for: id, in: period)
        else { return }
        session.updateTime(id, period: period, time: min(max(time, limits.lowerBound), limits.upperBound))
    }
}

/// "When: 2nd Half · 23:14", with Change opening the period and minute and
/// second wheels. A period end keeps its period; only its time can change.
struct EventTimeField: View {
    let match: Match
    let eventID: EventID
    @Binding var draft: EventTimeDraft

    var body: some View {
        if draft.isShown {
            VStack(alignment: .leading, spacing: 8) {
                SheetLabel("When")
                if isPeriodEnd {
                    Text(draft.period.displayName).font(.headline)
                } else {
                    Picker("Period", selection: $draft.period) {
                        ForEach(match.playedPeriods, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                HStack(spacing: 0) {
                    Picker("Minutes", selection: $draft.minutes) {
                        ForEach(0...Match.maxEventTime / 60, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Picker("Seconds", selection: $draft.seconds) {
                        ForEach(0..<60, id: \.self) { Text("\($0) sec").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                if let note = limitNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Button {
                draft.isShown = true
            } label: {
                Label("\(draft.period.displayName) · \(MatchClock.text(seconds: draft.time))", systemImage: "clock")
            }
            .accessibilityHint("Change when it happened")
        }
    }

    private var isPeriodEnd: Bool { match.event(eventID)?.kind == .periodEnd }

    /// Explains a time that will be brought within the period's limits.
    private var limitNote: String? {
        guard let limits = match.timeLimits(for: eventID, in: draft.period), !limits.contains(draft.time) else { return nil }
        if draft.time > limits.upperBound {
            return "\(draft.period.displayName) ended at \(MatchClock.text(seconds: limits.upperBound)), so it will be saved at that time."
        }
        return "The last event in \(draft.period.displayName) was at \(MatchClock.text(seconds: limits.lowerBound)), so it will be saved at that time."
    }
}

/// The details of an event with nothing to edit but its time: a period end,
/// or a card recorded on its own by an older version.
struct TimeOnlySheet: View {
    let session: MatchSession
    let eventID: EventID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let event = session.match.event(eventID) {
            EventSheetLayout(session: session, eventID: eventID, title: EventText.title(event, in: session.match),
                             undoTitle: event.kind == .periodEnd ? nil : "Delete",
                             onUndo: { session.deleteEvent(eventID); dismiss() },
                             onDone: { dismiss() }) {
                Text(EventText.detail(event, in: session.match))
                    .foregroundStyle(.secondary)
            }
            .presentationDetents([.medium, .large])
        } else {
            EventGoneView()
        }
    }
}

/// Shown if the event was deleted (e.g. undone) while its sheet was opening.
struct EventGoneView: View {
    var body: some View {
        ContentUnavailableView("This event is gone", systemImage: "flag.slash")
            .presentationDragIndicator(.visible)
    }
}

/// A small heading above a part of a sheet.
struct SheetLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

/// A note being edited on a sheet, collapsed behind "Add Note" until wanted.
struct NoteDraft {
    var text = ""
    var isShown = false
    private var loaded = false

    /// Starts from the event's note, once, so reopening a sheet shows it.
    mutating func load(_ note: String?) {
        guard !loaded else { return }
        loaded = true
        text = note ?? ""
        isShown = note != nil
    }

    /// The note to save: the text if the field was opened, otherwise the note as it was.
    func text(keeping existing: String?) -> String? {
        isShown ? text : existing
    }
}

struct NoteField: View {
    @Binding var draft: NoteDraft

    var body: some View {
        if draft.isShown {
            TextField("Anything worth remembering", text: $draft.text, axis: .vertical)
                .lineLimit(2...5)
                .padding(10)
                .background(.fill.tertiary, in: .rect(cornerRadius: 12))
        } else {
            Button("Add Note", systemImage: "text.bubble") { draft.isShown = true }
        }
    }
}

/// Options as chips, the picked one in gold.
struct ChoiceChips<Value: Hashable, ChipLabel: View>: View {
    let options: [Value]
    @Binding var selection: Value
    @ViewBuilder let label: (Value) -> ChipLabel

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { selection = option } label: {
                    label(option)
                        .font(MatchTheme.display(18))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .foregroundStyle(selected ? MatchTheme.goldInk : .primary)
                        .background(selected ? AnyShapeStyle(MatchTheme.gold) : AnyShapeStyle(.fill.tertiary),
                                    in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A referee's card in its colour.
struct CardSwatch: View {
    let card: CardType

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(MatchTheme.card(card))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("More sheet") {
    MoreSheet(teamName: "Commercials", side: .team1, canRecord: true) { _ in }
}

#Preview("Period end time") {
    let session = MatchSession.preview(.halfTime)
    return EventDetailsSheet(session: session, eventID: session.match.events.last!.id)
}

#Preview("Foul sheet") {
    let session = MatchSession.preview(.secondHalf)
    session.perform(.foul(.team2), at: .now)
    return EventDetailsSheet(session: session, eventID: session.match.events.last!.id)
}

#Preview("Substitution sheet") {
    let session = MatchSession.preview(.secondHalf)
    session.perform(.substitution(.team1), at: .now)
    return EventDetailsSheet(session: session, eventID: session.match.events.last!.id)
}

#Preview("Kickout sheet") {
    let session = MatchSession.preview(.secondHalf)
    session.perform(.kickout(.team1), at: .now)
    return EventDetailsSheet(session: session, eventID: session.match.events.last!.id)
}
#endif
