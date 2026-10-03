import MatchCore

/// The event drawer's list: every event, newest first, less the one the
/// last-event card already shows. Kept out of the view so it can be tested.
struct EventList {
    let events: [MatchEvent]

    /// `excluding` leaves out one event: the one on the last-event card.
    init(_ match: Match, excluding excluded: EventID? = nil) {
        events = match.eventsNewestFirst.filter { $0.id != excluded }
    }
}
