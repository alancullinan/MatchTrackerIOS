import MatchCore

/// The events list's sections: one per period with events, newest period
/// first and newest event first within it. Kept out of the view so it can be tested.
struct EventList {
    struct Section: Equatable {
        let period: MatchPeriod
        let events: [MatchEvent]
    }

    let sections: [Section]

    init(_ match: Match) {
        var sections: [Section] = []
        for event in match.eventsNewestFirst {
            if let last = sections.last, last.period == event.period {
                sections[sections.count - 1] = Section(period: last.period, events: last.events + [event])
            } else {
                sections.append(Section(period: event.period, events: [event]))
            }
        }
        self.sections = sections
    }
}
