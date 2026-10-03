import MatchCore
import SwiftUI

/// Every event in the match, newest first, shown in the match screen's event
/// drawer under the last-event card (which opens only when there's something to
/// list). Each row looks like the card, period included, so there are no
/// period headings. Tap one to change its details or time; swipe to delete it.
struct EventListView: View {
    let session: MatchSession
    /// An event to leave out: the one the last-event card shows above the list.
    var excluding: EventID?
    /// Opens the event's details sheet.
    let onSelect: (EventID) -> Void

    private var match: Match { session.match }

    var body: some View {
        List(EventList(match, excluding: excluding).events, id: \.id) { event in
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// The card's padding, so the rows line up with it.
    private static let rowInsets = EdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 12)

    /// Styled like the last-event card, so the drawer reads as one list.
    private func row(_ event: MatchEvent) -> some View {
        HStack(spacing: 12) {
            EventIcon(event)
            VStack(alignment: .leading, spacing: 2) {
                Text(EventText.title(event, in: match))
                    .font(.system(size: 17, weight: .bold))
                Text(EventText.detail(event, in: match))
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
