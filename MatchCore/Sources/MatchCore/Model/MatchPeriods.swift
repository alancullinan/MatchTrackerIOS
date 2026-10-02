import Foundation

extension MatchPeriod {
    /// Events can only be recorded while the ball is in play.
    public var isPlaying: Bool {
        switch self {
        case .firstHalf, .secondHalf, .extraTimeFirstHalf, .extraTimeSecondHalf: true
        case .notStarted, .halfTime, .fullTime, .extraTimeHalfTime, .matchOver: false
        }
    }

    /// The name to show. `.matchOver` is only reached after extra time, so it
    /// reads "Full Time (AET)"; the raw value stays "Match Over" for PWA backups.
    public var displayName: String {
        switch self {
        case .matchOver: "Full Time (AET)"
        default: rawValue
        }
    }

    /// Position in play order, for sorting.
    var order: Int {
        MatchPeriod.allCases.firstIndex(of: self)!
    }

    /// The break a playing period ends into. `nil` for periods that aren't playing.
    var periodAfterEnd: MatchPeriod? {
        switch self {
        case .firstHalf: .halfTime
        case .secondHalf: .fullTime
        case .extraTimeFirstHalf: .extraTimeHalfTime
        case .extraTimeSecondHalf: .matchOver
        default: nil
        }
    }
}

/// The match's progress through its periods. Every change is a no-op when it
/// doesn't apply (it returns `false`), so a double-tap or a stale button can't
/// skip a period or record a second period end.
extension Match {
    public var canRecordEvents: Bool { clock.period.isPlaying }

    /// The playing period `start` would begin from the current break, if any.
    /// Full Time ends a match unless extra time is started from it; there is no
    /// separate step to finish a match.
    public var nextPlayingPeriod: MatchPeriod? {
        switch clock.period {
        case .notStarted: .firstHalf
        case .halfTime: .secondHalf
        case .fullTime: .extraTimeFirstHalf
        case .extraTimeHalfTime: .extraTimeSecondHalf
        default: nil
        }
    }

    /// From a break, starts the next playing period from 0:00. In a paused
    /// playing period, resumes the clock.
    @discardableResult
    public mutating func start(at now: Date) -> Bool {
        if let next = nextPlayingPeriod {
            clock = MatchClock(period: next, bankedSeconds: 0, runningSince: now)
            return true
        }
        guard clock.period.isPlaying, !clock.isRunning else { return false }
        clock.start(at: now)
        return true
    }

    /// Pauses the clock in a playing period.
    @discardableResult
    public mutating func pause(at now: Date) -> Bool {
        guard clock.isRunning else { return false }
        clock.pause(at: now)
        return true
    }

    /// Ends the current playing period: records a period-end event with the
    /// period and its final time, and moves to the following break (or to
    /// Match Over after extra time). The clock stops; a break starts at 0:00.
    @discardableResult
    public mutating func endPeriod(at now: Date) -> Bool {
        guard let after = clock.period.periodAfterEnd else { return false }
        let finalTime = clock.elapsed(at: now)
        events.append(MatchEvent(period: clock.period, time: finalTime, kind: .periodEnd))
        clock = MatchClock(period: after, bankedSeconds: after == .matchOver ? finalTime : 0)
        return true
    }

    /// Records an event at the current period and time. Returns `nil`, recording
    /// nothing, outside a playing period.
    @discardableResult
    public mutating func record(_ kind: MatchEvent.Kind, note: String? = nil, at now: Date) -> MatchEvent? {
        guard canRecordEvents, kind != .periodEnd else { return nil }
        let event = MatchEvent(period: clock.period, time: clock.elapsed(at: now), note: note, kind: kind)
        events.append(event)
        return event
    }
}
