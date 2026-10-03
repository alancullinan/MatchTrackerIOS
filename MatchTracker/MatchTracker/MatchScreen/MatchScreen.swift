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
            GrassBackground()
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

/// The live match: the clock with its button, both teams with their flags, and the
/// last event, which drags up into a drawer of every event.
struct MatchScreen: View {
    @Bindable var session: MatchSession

    @State private var isEditing = false
    @State private var moreFor: TeamSide?
    /// Whether the event drawer is open, from the clock down.
    @State private var showsEvents: Bool
    /// Where the clock capsule ends, which is how far the drawer opens.
    @State private var clockBottom: CGFloat = 0
    /// The last-event card's height, kept clear below the team cards.
    @State private var cardHeight: CGFloat = 0
    /// The room between the clock and the bottom: how tall the drawer opens.
    @State private var drawerSpace: CGFloat = 0
    /// How far the drawer has been dragged (down is positive); springs back on release.
    @GestureState(resetTransaction: Transaction(animation: MatchScreen.drawerAnimation))
    private var dragHeight: CGFloat = 0
    @State private var showsStats = false
    @State private var editsClock = false
    @State private var teamSheetFor: TeamSide?

    /// `showsEvents` opens with the event drawer up, for Previews.
    init(session: MatchSession, showsEvents: Bool = false) {
        self.session = session
        _showsEvents = State(initialValue: showsEvents)
    }

    /// How long Undo stays on the last-event card after a change.
    private static let undoSeconds: Duration = .seconds(6)

    private var match: Match { session.match }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !match.competition.isEmpty {
                    Text(match.competition)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                let control = ClockControl(match: match)
                ClockView(match: match, hint: control.hint,
                          onAdjust: { if match.clock.period.isPlaying { editsClock = true } }) {
                    ClockButton(control: control) { session.perform($0, at: .now) }
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.screenSpace)).maxY } action: {
                    clockBottom = $0
                }
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
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: cardHeight + 8) }
        .overlay { thumbZone }
        .coordinateSpace(.named(Self.screenSpace))
        .background { GrassBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        // Glass on the grass reads best in dark, so this screen and its sheets always are.
        .matchScreenAppearance()
        .navigationDestination(isPresented: $showsStats) {
            StatsView(session: session)
                .matchScreenAppearance()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Stats", systemImage: "chart.bar") { showsStats = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("More Options", systemImage: "ellipsis") {
                    Button("Add Note", systemImage: "text.bubble") { session.perform(.note(nil), at: .now) }
                        .disabled(!match.canRecordEvents)
                    Button("Adjust Clock", systemImage: "clock.arrow.2.circlepath") { editsClock = true }
                        .disabled(!match.clock.period.isPlaying)
                    Button("Edit Match", systemImage: "pencil") { isEditing = true }
                    Section("Team Sheets") {
                        ForEach(TeamSide.allCases, id: \.self) { side in
                            Button(EventText.teamName(match[side]), systemImage: "person.3") { teamSheetFor = side }
                        }
                    }
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
        .sheet(isPresented: $editsClock) {
            ClockEditor(session: session)
                .matchSheetAppearance()
        }
        .sheet(isPresented: $isEditing, onDismiss: session.reload) {
            MatchFormView(editing: match)
                .matchSheetAppearance()
        }
        .sheet(item: Binding(get: { moreFor.map(SheetTeam.init) }, set: { moreFor = $0?.side })) { item in
            MoreSheet(teamName: EventText.teamName(match[item.side]), side: item.side, canRecord: match.canRecordEvents,
                      onRecord: { session.perform($0, at: .now) },
                      onTeamSheet: { teamSheetFor = item.side })
                .matchSheetAppearance()
        }
        .sheet(item: Binding(get: { teamSheetFor.map(SheetTeam.init) }, set: { teamSheetFor = $0?.side })) { item in
            TeamSheetEditor(session: session, side: item.side)
                .matchSheetAppearance()
        }
        .sheet(item: Binding(get: { session.detailsEvent.map(SheetEvent.init) },
                             set: { session.detailsEvent = $0?.eventID })) { item in
            EventDetailsSheet(session: session, eventID: item.eventID)
                .matchSheetAppearance()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: session.changeCount)
        // The Lock Screen and Dynamic Island follow every change, including from the event list.
        .onChange(of: session.match, initial: true) { _, match in LiveActivities.update(for: match) }
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

    private static let screenSpace = "matchScreen"

    /// The bottom of the screen, under the thumb: the event drawer. Closed, it's
    /// the last-event card; dragged up, the card rides up with it and every event
    /// shows below, up to the clock.
    @ViewBuilder
    private var thumbZone: some View {
        let undoing = session.undoable != nil
        VStack(spacing: 0) {
            lastEventCard
                .overlay(alignment: .top) {
                    if canOpenDrawer { DrawerHandle().padding(.top, 6) }
                }
                .contentShape(.rect)
                .onTapGesture { setShowsEvents(!showsEvents) }
                .gesture(drawerDrag)
                .accessibilityActions {
                    if canOpenDrawer {
                        Button(showsEvents ? "Hide Events" : "Show Events") { setShowsEvents(!showsEvents) }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
            // Once the card is measured, so the drawer never opens with the list showing.
            if canOpenDrawer, cardHeight > 0 {
                Divider().padding(.horizontal, 20)
                // Always its open size, so dragging only uncovers more of it rather
                // than laying the list out again each frame.
                EventListView(session: session, excluding: cardEventID) { session.detailsEvent = $0 }
                    .frame(height: max(drawerSpace - cardHeight - 1, 0))
            }
        }
        .frame(height: cardHeight > 0 ? drawerHeight : nil, alignment: .top)
        .clipShape(.rect(cornerRadius: 38))
        .contentShape(.rect(cornerRadius: 38))
        .matchGlass(in: .rect(cornerRadius: 38))
        .overlay {
            if undoing {
                RoundedRectangle(cornerRadius: 38).strokeBorder(MatchTheme.gold, lineWidth: 2)
            }
        }
        .animation(.default, value: undoing)
        .opacity(hasLastEvent ? 1 : 0)
        .padding(.horizontal, 8)
        .padding(.top, clockBottom + 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { drawerSpace = $0 - clockBottom - 8 }
        // Closes when the last listed event is deleted or undone.
        .onChange(of: canOpenDrawer) { _, canOpen in if !canOpen { setShowsEvents(false) } }
    }

    /// The event the card shows, left out of the list below it.
    private var cardEventID: EventID? {
        if case .periodStart = session.undoable { return nil }
        return match.events.last?.id
    }

    /// Whether there's anything to list under the card. With only the card's
    /// event, there isn't, so the drawer stays closed.
    private var canOpenDrawer: Bool {
        !EventList(match, excluding: cardEventID).events.isEmpty
    }

    /// Whether there's a last event (or a period start to undo) to show.
    private var hasLastEvent: Bool {
        if case .periodStart = session.undoable { return true }
        return !match.events.isEmpty
    }

    /// The drawer's height: the card's when closed, up to the clock when open,
    /// following the finger while dragged.
    private var drawerHeight: CGFloat {
        guard canOpenDrawer else { return cardHeight }
        let open = max(drawerSpace, cardHeight)
        let base = showsEvents ? open : cardHeight
        return min(max(base - dragHeight, cardHeight), open)
    }

    /// Drags the drawer with the finger; on release it settles open or closed,
    /// whichever the flick lands nearer. Measured on the screen, not the card,
    /// which moves under the finger. (A tap on the card also opens or closes it.)
    private var drawerDrag: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragHeight) { drag, height, _ in height = drag.translation.height }
            .onEnded { drag in
                let open = max(drawerSpace, cardHeight)
                let base = showsEvents ? open : cardHeight
                let landing = base - drag.predictedEndTranslation.height
                setShowsEvents(landing > (open + cardHeight) / 2)
            }
    }

    private func setShowsEvents(_ shows: Bool) {
        guard shows != showsEvents, !shows || canOpenDrawer else { return }
        withAnimation(Self.drawerAnimation) { showsEvents = shows }
    }

    private static let drawerAnimation = Animation.spring(duration: 0.35)

    @ViewBuilder
    private var lastEventCard: some View {
        let showsUndo = session.undoable != nil
        if case .periodStart(let period) = session.undoable {
            LastEventCard(title: "\(period.displayName) started", detail: "The clock is running",
                          icon: nil, showsUndo: true, onUndo: { session.undo() })
        } else if let event = match.events.last {
            LastEventCard(title: EventText.title(event, in: match), detail: EventText.detail(event, in: match),
                          icon: EventIcon(event), showsUndo: showsUndo, onUndo: { session.undo() },
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


}

#if DEBUG
#Preview("Opened from the list") {
    // Goes through MatchScreenDestination, as tapping a match in the list does.
    NavigationStack { MatchScreenDestination(stored: MatchSession.previewStored(.secondHalf)) }
        .modelContainer(MatchSession.previewContainer)
}

#Preview("Not started, no colours") {
    NavigationStack { MatchScreen(session: .preview(.notStarted)) }
}

#Preview("Event drawer open") {
    NavigationStack { MatchScreen(session: .preview(.secondHalf), showsEvents: true) }
}

#Preview("1st half, running") {
    NavigationStack { MatchScreen(session: .preview(.firstHalf)) }
}

#Preview("1st half, paused") {
    NavigationStack { MatchScreen(session: .preview(.paused)) }
}

#Preview("Half time") {
    NavigationStack { MatchScreen(session: .preview(.halfTime)) }
}

#Preview("2nd half, running") {
    NavigationStack { MatchScreen(session: .preview(.secondHalf)) }
}

#Preview("Just after a card") {
    let session = MatchSession.preview(.secondHalf)
    session.perform(.foul(.team2), at: .now)
    session.updateFoul(session.match.events.last!.id, outcome: .free, card: .black, player: nil, note: nil)
    session.detailsEvent = nil
    return NavigationStack { MatchScreen(session: session) }
}

#Preview("Full time") {
    NavigationStack { MatchScreen(session: .preview(.fullTime)) }
}

#Preview("Full time after extra time") {
    NavigationStack { MatchScreen(session: .preview(.fullTimeAfterExtraTime)) }
}

#Preview("Long hurling scores") {
    NavigationStack { MatchScreen(session: .preview(.longScores)) }
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
