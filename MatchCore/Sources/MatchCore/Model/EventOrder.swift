extension Match {
    /// Events oldest first: by period in play order, then by time within the
    /// period. A period end always comes last in its period, even if an edited
    /// event's time is later. Events at the same moment keep the order they were
    /// recorded in. Computed every time, so it stays right after time or period edits.
    public var eventsInOrder: [MatchEvent] {
        events.enumerated().sorted { a, b in
            let (x, y) = (a.element, b.element)
            if x.period != y.period { return x.period.order < y.period.order }
            let (xEnds, yEnds) = (x.kind == .periodEnd, y.kind == .periodEnd)
            if xEnds != yEnds { return yEnds }
            if x.time != y.time { return x.time < y.time }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Events newest first, for the event list.
    public var eventsNewestFirst: [MatchEvent] {
        eventsInOrder.reversed()
    }

    /// The score straight after `eventID`, counting it and everything before it
    /// in time order. A period end's score is the score when the period ended.
    /// `nil` if the match has no such event.
    public func score(_ side: TeamSide, through eventID: EventID) -> Score? {
        let ordered = eventsInOrder
        guard let index = ordered.firstIndex(where: { $0.id == eventID }) else { return nil }
        return Score(of: side, in: ordered[...index])
    }
}
