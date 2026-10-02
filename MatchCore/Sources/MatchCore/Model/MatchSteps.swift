import Foundation

/// What the match screen's main button does next: start the next playing
/// period from a break, or end the one being played.
public enum MatchStep: Hashable, Sendable {
    case start(MatchPeriod)
    case end(MatchPeriod)

    /// The button's text.
    public var title: String {
        switch self {
        case .start(.firstHalf): "Start 1st Half"
        case .start(.secondHalf): "Start 2nd Half"
        case .start(.extraTimeFirstHalf): "Start Extra Time"
        case .start(.extraTimeSecondHalf): "Start ET 2nd Half"
        case .end(.firstHalf): "End 1st Half"
        case .end(.secondHalf): "End 2nd Half"
        case .end(.extraTimeFirstHalf): "End ET 1st Half"
        case .end(.extraTimeSecondHalf): "End Extra Time"
        // Steps only ever name playing periods.
        case .start(let period), .end(let period): period.displayName
        }
    }
}

extension Match {
    /// The next step, or `nil` once the match is over after extra time.
    /// During play it is always ending the period; pausing is separate.
    public var nextStep: MatchStep? {
        if clock.period.isPlaying { return .end(clock.period) }
        return nextPlayingPeriod.map(MatchStep.start)
    }

    /// Takes `nextStep`. Returns `false`, changing nothing, if there is none.
    @discardableResult
    public mutating func takeNextStep(at now: Date) -> Bool {
        switch nextStep {
        case .start: start(at: now)
        case .end: endPeriod(at: now)
        case nil: false
        }
    }

    /// The most recent period end, e.g. to show how long the last half ran
    /// during a break.
    public var lastPeriodEnd: MatchEvent? {
        eventsInOrder.last { $0.kind == .periodEnd }
    }

    /// Removes the most recently recorded event and returns it.
    ///
    /// A period end can only be undone during the break it led to: the match
    /// goes back into that period, paused at the time it ended, so play can
    /// resume. Once the next period has started, returns `nil` and changes nothing.
    @discardableResult
    public mutating func undoLastEvent() -> MatchEvent? {
        guard let last = events.last else { return nil }
        if last.kind == .periodEnd {
            guard clock.period == last.period.periodAfterEnd else { return nil }
            clock = MatchClock(period: last.period, bankedSeconds: last.time)
        }
        return events.removeLast()
    }

    /// Undoes starting the current playing period, going back to the break
    /// before it. Only while nothing has been recorded in the period; returns
    /// `false` and changes nothing otherwise. Meant for straight after a start
    /// tapped by mistake: the period's clock time is dropped.
    @discardableResult
    public mutating func undoPeriodStart() -> Bool {
        guard clock.period.isPlaying,
              !events.contains(where: { $0.period == clock.period }),
              let breakBefore = clock.period.breakBefore
        else { return false }
        clock = MatchClock(period: breakBefore)
        return true
    }
}

extension MatchPeriod {
    /// The break a playing period starts from. `nil` for periods that aren't playing.
    var breakBefore: MatchPeriod? {
        switch self {
        case .firstHalf: .notStarted
        case .secondHalf: .halfTime
        case .extraTimeFirstHalf: .fullTime
        case .extraTimeSecondHalf: .extraTimeHalfTime
        default: nil
        }
    }
}

extension MatchClock {
    /// Clock text for whole seconds: "07:05", "63:40". Minutes keep counting
    /// past an hour, as on a match clock.
    public static func text(seconds: Int) -> String {
        let seconds = max(0, seconds)
        let minutes = seconds / 60
        let rest = seconds % 60
        return (minutes < 10 ? "0" : "") + "\(minutes):" + (rest < 10 ? "0" : "") + "\(rest)"
    }
}

extension MatchEvent {
    /// The match minute the event happened in, as written on a report: the
    /// first minute of a period is 1'.
    public var minute: Int { time / 60 + 1 }
}
