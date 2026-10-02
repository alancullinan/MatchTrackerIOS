import MatchCore
import SwiftData
import SwiftUI

/// Opens a stored match on the match screen, or explains that it can't be read.
struct MatchScreenDestination: View {
    let stored: StoredMatch

    @Environment(\.modelContext) private var context
    @State private var session: MatchSession?
    @State private var unreadable = false

    var body: some View {
        if let session {
            MatchScreen(session: session)
        } else if unreadable {
            ContentUnavailableView(
                "This Match Can't Be Read",
                systemImage: "exclamationmark.triangle",
                description: Text("It may have been saved by a newer version of the app. Nothing has been changed.")
            )
        } else {
            // A real view while loading: a task on an empty view never runs.
            PitchBackground()
                .task { load() }
        }
    }

    private func load() {
        guard session == nil else { return }
        if let match = try? stored.match() {
            session = MatchSession(match: match, context: context)
        } else {
            unreadable = true
        }
    }
}

/// Identifiable wrappers, so the sheets can be driven by optional values.
private struct SheetTeam: Identifiable { let side: TeamSide; var id: TeamSide { side } }
private struct SheetEvent: Identifiable { let eventID: EventID; var id: EventID { eventID } }

/// The live match: clock, both teams with their flags, and the next step.
struct MatchScreen: View {
    @Bindable var session: MatchSession

    @State private var isEditing = false
    @State private var moreFor: TeamSide?

    /// How long Undo stays on the last-event card after a change.
    private static let undoSeconds: Duration = .seconds(6)

    private var match: Match { session.match }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !match.competition.isEmpty {
                    Text(match.competition.uppercased())
                        .font(MatchTheme.display(15))
                        .tracking(2)
                        .foregroundStyle(MatchTheme.muted)
                        .multilineTextAlignment(.center)
                }
                ClockView(match: match)
                ForEach(TeamSide.allCases, id: \.self) { side in
                    TeamCard(team: match[side], score: match.score(side), flagsEnabled: match.canRecordEvents,
                             onScore: { session.perform(.score(side, $0), at: .now) },
                             onMore: { moreFor = side })
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { thumbZone }
        .background { PitchBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More Options", systemImage: "ellipsis") {
                    Button("Add Note", systemImage: "text.bubble") { session.perform(.note(nil), at: .now) }
                        .disabled(!match.canRecordEvents)
                    Button("Edit Match", systemImage: "pencil") { isEditing = true }
                    Section("Scorer Sheet") {
                        ForEach(TeamSide.allCases, id: \.self) { side in
                            Toggle("Ask for \(EventText.teamName(match[side])) scorers", isOn: Binding(
                                get: { match[side].asksForScorers },
                                set: { session.setAsksForScorers($0, for: side) }
                            ))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: session.reload) {
            MatchFormView(editing: match)
        }
        .sheet(item: Binding(get: { moreFor.map(SheetTeam.init) }, set: { moreFor = $0?.side })) { item in
            MoreSheet(teamName: EventText.teamName(match[item.side]), side: item.side, canRecord: match.canRecordEvents) {
                session.perform($0, at: .now)
            }
        }
        .sheet(item: Binding(get: { session.detailsEvent.map(SheetEvent.init) },
                             set: { session.detailsEvent = $0?.eventID })) { item in
            EventDetailsSheet(session: session, eventID: item.eventID)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: session.changeCount)
        .task(id: session.undoable) {
            guard session.undoable != nil else { return }
            try? await Task.sleep(for: Self.undoSeconds)
            if !Task.isCancelled { session.clearUndo() }
        }
        .alert(
            "Couldn't Save the Match",
            isPresented: Binding(get: { session.saveError != nil }, set: { if !$0 { session.saveError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(session.saveError ?? "")
        }
    }

    /// The bottom of the screen, under the thumb: the last event and the next step.
    private var thumbZone: some View {
        VStack(spacing: 10) {
            lastEventCard
            HStack(spacing: 10) {
                if match.clock.period.isPlaying {
                    Button {
                        session.perform(match.clock.isRunning ? .pause : .resume, at: .now)
                    } label: {
                        Image(systemName: match.clock.isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 58, height: 58)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                    .accessibilityLabel(match.clock.isRunning ? "Pause clock" : "Resume clock")
                }
                Button {
                    session.perform(.nextStep, at: .now)
                } label: {
                    Text((match.nextStep?.title ?? match.clock.period.displayName).uppercased())
                        .font(MatchTheme.display(22, .bold))
                        .tracking(2)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .foregroundStyle(match.nextStep == nil ? MatchTheme.muted : MatchTheme.goldInk)
                        .background(match.nextStep == nil ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(MatchTheme.gold),
                                    in: .rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .disabled(match.nextStep == nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var lastEventCard: some View {
        let showsUndo = session.undoable != nil
        if case .periodStart(let period) = session.undoable {
            LastEventCard(title: "\(period.displayName) started", detail: "The clock is running",
                          icon: nil, showsUndo: true) { session.undo() }
        } else if let event = match.events.last {
            LastEventCard(title: EventText.title(event, in: match), detail: EventText.detail(event, in: match),
                          icon: icon(for: event), showsUndo: showsUndo, onUndo: { session.undo() },
                          onDetails: hasDetails(event) ? { session.detailsEvent = event.id } : nil)
        }
    }

    /// Whether the event has a details sheet to reopen.
    private func hasDetails(_ event: MatchEvent) -> Bool {
        switch event.kind {
        case .shot, .foul, .kickout, .substitution, .note: true
        case .card, .periodEnd: false
        }
    }

    /// A flag for a shot (filled for a score, outlined for a miss), the card
    /// for a foul with one, and a symbol for anything else.
    private func icon(for event: MatchEvent) -> LastEventCard.Icon? {
        switch event.kind {
        case .shot(_, _, let outcome, _):
            switch outcome {
            case .goal: .flag(MatchTheme.goal)
            case .point: .flag(MatchTheme.point)
            case .twoPointer: .flag(MatchTheme.twoPointer)
            case .wide, .saved, .droppedShort, .offPost: .missFlag
            }
        case .foul(_, _, _, let card?), .card(_, _, let card): .card(card)
        case .foul: .symbol("hand.raised.fill")
        case .kickout: .symbol("arrow.up.forward")
        case .substitution: .symbol("arrow.left.arrow.right")
        case .note: .symbol("text.bubble")
        case .periodEnd: nil
        }
    }
}

#if DEBUG
#Preview("Opened from the list") {
    // Goes through MatchScreenDestination, as tapping a match in the list does.
    NavigationStack { MatchScreenDestination(stored: MatchSession.previewStored(.secondHalf)) }
        .modelContainer(MatchSession.previewContainer)
}

#Preview("2nd half, running") {
    NavigationStack { MatchScreen(session: .preview(.secondHalf)) }
}

#Preview("Just after a card") {
    let session = MatchSession.preview(.secondHalf)
    session.perform(.foul(.team2, card: .black), at: .now)
    session.detailsEvent = nil
    return NavigationStack { MatchScreen(session: session) }
}

#Preview("Not started, no colours") {
    NavigationStack { MatchScreen(session: .preview(.notStarted)) }
}

#Preview("Half time") {
    NavigationStack { MatchScreen(session: .preview(.halfTime)) }
}

#Preview("Full time after extra time") {
    NavigationStack { MatchScreen(session: .preview(.fullTimeAfterExtraTime)) }
}

extension MatchSession {
    /// The previews' own in-memory store, kept for as long as the previews run.
    static let previewContainer = try! Store.container(inMemory: true)

    /// A session on a sample match in `state`, saved in an in-memory store.
    static func preview(_ state: SampleMatches.ScreenState) -> MatchSession {
        let match = SampleMatches.screen(state)
        let context = previewContainer.mainContext
        try? context.store(match)
        return MatchSession(match: match, context: context)
    }

    /// A sample match in `state`, stored in the previews' in-memory store.
    static func previewStored(_ state: SampleMatches.ScreenState) -> StoredMatch {
        try! previewContainer.mainContext.store(SampleMatches.screen(state))
    }
}
#endif
