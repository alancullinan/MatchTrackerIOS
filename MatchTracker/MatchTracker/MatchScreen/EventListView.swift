import MatchCore
import SwiftUI

/// Every event in the match, newest first, grouped by period. Tap one to
/// change its details or time; swipe to delete it.
struct EventListView: View {
    let session: MatchSession

    @State private var editing: EventID?

    private var match: Match { session.match }

    var body: some View {
        let list = EventList(match)
        List {
            ForEach(list.sections, id: \.period) { section in
                Section(section.period.displayName) {
                    ForEach(section.events, id: \.id) { event in
                        Button { editing = event.id } label: { row(event) }
                            .tint(.primary)
                            .swipeActions {
                                // A period end is part of the match's progress, so it can't be deleted here.
                                if event.kind != .periodEnd {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        session.deleteEvent(event.id)
                                    }
                                }
                            }
                    }
                }
            }
        }
        .overlay {
            if list.sections.isEmpty {
                ContentUnavailableView("No Events Yet", systemImage: "list.bullet",
                                       description: Text("Scores, fouls and everything else appear here as they're recorded."))
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(get: { editing.map(EditedEvent.init) }, set: { editing = $0?.eventID })) { item in
            EventDetailsSheet(session: session, eventID: item.eventID)
                .matchSheetAppearance()
        }
    }

    private func row(_ event: MatchEvent) -> some View {
        HStack(spacing: 12) {
            EventIcon(event)
            VStack(alignment: .leading, spacing: 2) {
                Text(EventText.title(event, in: match))
                    .font(.callout.weight(.semibold))
                Text(EventText.detail(event, in: match, showsPeriod: false))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                // A note's text is its title; any other event's note goes underneath.
                if let note = event.note, event.type != .note {
                    Text(note)
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct EditedEvent: Identifiable {
    let eventID: EventID
    var id: EventID { eventID }
}

#if DEBUG
#Preview("Events") {
    NavigationStack { EventListView(session: .preview(.fullTimeAfterExtraTime)) }
}

#Preview("No events") {
    NavigationStack { EventListView(session: .preview(.notStarted)) }
}
#endif
