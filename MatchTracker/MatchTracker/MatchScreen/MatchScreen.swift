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
        Group {
            if let session {
                MatchScreen(session: session)
            } else if unreadable {
                ContentUnavailableView(
                    "This Match Can't Be Read",
                    systemImage: "exclamationmark.triangle",
                    description: Text("It may have been saved by a newer version of the app. Nothing has been changed.")
                )
            }
        }
        .task {
            guard session == nil else { return }
            if let match = try? stored.match() {
                session = MatchSession(match: match, context: context)
            } else {
                unreadable = true
            }
        }
    }
}

/// The live match: clock, both teams with their flags, and the next step.
struct MatchScreen: View {
    @Bindable var session: MatchSession

    @State private var isEditing = false

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
                    TeamCard(team: match[side], score: match.score(side), flagsEnabled: match.canRecordEvents) { outcome in
                        session.perform(.score(side, outcome), at: .now)
                    }
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
                    Button("Edit Match", systemImage: "pencil") { isEditing = true }
                }
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: session.reload) {
            MatchFormView(editing: match)
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
                          flag: nil, showsUndo: true) { session.undo() }
        } else if let event = match.events.last {
            LastEventCard(title: EventText.title(event, in: match), detail: EventText.detail(event, in: match),
                          flag: flag(for: event), showsUndo: showsUndo) { session.undo() }
        }
    }

    /// A filled flag for a score, an outline for a miss, none for anything else.
    private func flag(for event: MatchEvent) -> LastEventCard.Flag? {
        guard case .shot(_, _, let outcome, _) = event.kind else { return nil }
        switch outcome {
        case .goal: return .filled(MatchTheme.goal)
        case .point: return .filled(MatchTheme.point)
        case .twoPointer: return .filled(MatchTheme.twoPointer)
        case .wide, .saved, .droppedShort, .offPost: return .outline
        }
    }
}

#if DEBUG
#Preview("2nd half, running") {
    NavigationStack { MatchScreen(session: .preview(.secondHalf)) }
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
    private static let previewContainer = try! Store.container(inMemory: true)

    /// A session on a sample match in `state`, saved in an in-memory store.
    static func preview(_ state: SampleMatches.ScreenState) -> MatchSession {
        let match = SampleMatches.screen(state)
        let context = previewContainer.mainContext
        try? context.store(match)
        return MatchSession(match: match, context: context)
    }
}
#endif
