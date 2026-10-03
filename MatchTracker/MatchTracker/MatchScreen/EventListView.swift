import MatchCore
import SwiftUI

/// Every event in the match, newest first, grouped by period, shown in the
/// match screen's event drawer. Tap one to change its details or time; swipe to delete it.
struct EventListView: View {
    let session: MatchSession
    /// An event to leave out: the one the last-event card shows above the list.
    var excluding: EventID?
    /// Opens the event's details sheet.
    let onSelect: (EventID) -> Void

    private var match: Match { session.match }

    var body: some View {
        let list = EventList(match, excluding: excluding)
        List {
            ForEach(list.sections, id: \.period) { section in
                Section(section.period.displayName) {
                    ForEach(section.events, id: \.id) { event in
                        Button { onSelect(event.id) } label: { row(event) }
                            .tint(.primary)
                            .listRowBackground(Color.clear)
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if list.sections.isEmpty {
                ContentUnavailableView("No Events Yet", systemImage: "list.bullet",
                                       description: Text("Scores, fouls and everything else appear here as they're recorded."))
            }
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

#if DEBUG
#Preview("Events") {
    EventListView(session: .preview(.fullTimeAfterExtraTime), onSelect: { _ in })
        .background { GrassBackground() }
        .matchScreenAppearance()
}

#Preview("No events") {
    EventListView(session: .preview(.notStarted), onSelect: { _ in })
        .background { GrassBackground() }
        .matchScreenAppearance()
}
#endif
