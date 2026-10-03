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

/// The live match: clock, both teams with their flags, and the next step.
struct MatchScreen: View {
    @Bindable var session: MatchSession

    @State private var isEditing = false
    @State private var moreFor: TeamSide?
    @State private var showsEvents = false
    @State private var editsClock = false
    @State private var teamSheetFor: TeamSide?

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
                ClockView(match: match, hint: clockHint,
                          onAdjust: { if match.clock.period.isPlaying { editsClock = true } }) {
                    clockButton
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
        .safeAreaInset(edge: .bottom) { thumbZone }
        .background { GrassBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        // Glass on the grass reads best in dark, so this screen and its sheets always are.
        .matchScreenAppearance()
        .navigationDestination(isPresented: $showsEvents) {
            EventListView(session: session)
                .matchScreenAppearance()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Events", systemImage: "list.bullet") { showsEvents = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("More Options", systemImage: "ellipsis") {
                    Button("Add Note", systemImage: "text.bubble") { session.perform(.note(nil), at: .now) }
                        .disabled(!match.canRecordEvents)
                    Button("Adjust Clock", systemImage: "clock.arrow.2.circlepath") { editsClock = true }
                        .disabled(!match.clock.period.isPlaying)
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

    /// The gold button in the clock capsule: pauses and resumes play.
    private var clockButton: some View {
        let playing = match.clock.period.isPlaying
        return Button {
            session.perform(match.clock.isRunning ? .pause : .resume, at: .now)
        } label: {
            ClockButtonFace(systemImage: playing && match.clock.isRunning ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.plain)
        .disabled(!playing)
        .accessibilityLabel(match.clock.isRunning ? "Pause clock" : "Resume clock")
    }

    private var clockHint: String {
        guard match.clock.period.isPlaying else { return "" }
        return match.clock.isRunning ? "Tap to pause" : "Tap to resume"
    }

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
