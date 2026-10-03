import MatchCore
import SwiftUI

/// Every event in the match, newest first, grouped by period, shown in the
/// match screen's event drawer (which opens only when there's something to list). Tap one to change its details or time; swipe to delete it.
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
                Section {
                    ForEach(section.events, id: \.id) { event in
                        Button { onSelect(event.id) } label: { row(event) }
                            .tint(.primary)
                            .listRowBackground(Color.clear)
                            .listRowInsets(Self.rowInsets)
                            .swipeActions {
                                // A period end is part of the match's progress, so it can't be deleted here.
                                if event.kind != .periodEnd {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        session.deleteEvent(event.id)
                                    }
                                }
                            }
                    }
                } header: {
                    Text(section.period.displayName)
                        .listRowInsets(Self.rowInsets)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// In line with the last-event card above the list.
    private static let rowInsets = EdgeInsets(top: 10, leading: 22, bottom: 10, trailing: 12)

    /// Styled like the last-event card, so the drawer reads as one list.
    private func row(_ event: MatchEvent) -> some View {
        HStack(spacing: 12) {
            EventIcon(event)
            VStack(alignment: .leading, spacing: 2) {
                Text(EventText.title(event, in: match))
                    .font(.system(size: 17, weight: .bold))
                Text(EventText.detail(event, in: match, showsPeriod: false))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
                // A note's text is its title; any other event's note goes underneath.
                if let note = event.note, event.type != .note {
                    Text(note)
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Events") {
    EventListView(session: .preview(.fullTimeAfterExtraTime), onSelect: { _ in })
        .background { GrassBackground() }
        .matchScreenAppearance()
}
#endif
