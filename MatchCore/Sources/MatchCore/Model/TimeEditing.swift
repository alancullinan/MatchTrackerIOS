import Foundation

// Correcting times after the fact: the running clock (e.g. started late) and
// any event's time and period (e.g. a half ended a minute late).

extension Match {
    /// The latest time an event can be given: 99:59, the most a match clock shows.
    public static let maxEventTime = 99 * 60 + 59

    /// Moves the clock of the period being played on or back by `seconds`,
    /// keeping it running or paused as it was. It never goes below 0:00.
    /// Returns `false`, changing nothing, outside a playing period or for 0.
    @discardableResult
    public mutating func adjustClock(by seconds: Int, at now: Date) -> Bool {
        guard clock.period.isPlaying, seconds != 0 else { return false }
        let wasRunning = clock.isRunning
        let adjusted = max(0, clock.elapsed(at: now) + seconds)
        clock = MatchClock(period: clock.period, bankedSeconds: adjusted, runningSince: wasRunning ? now : nil)
        return true
    }

    /// The playing periods reached so far, in play order: those an event can be moved to.
    public var playedPeriods: [MatchPeriod] {
        MatchPeriod.allCases.filter { $0.isPlaying && $0.order <= clock.period.order }
    }

    /// The times event `id` can be given in `period`, or `nil` if it can't be
    /// moved there. An event can go in any period played so far, up to the time
    /// that period ended. A period end stays in its own period, no earlier
    /// than the last event in it.
    public func timeLimits(for id: EventID, in period: MatchPeriod) -> ClosedRange<Int>? {
        guard let event = event(id) else { return nil }
        if event.kind == .periodEnd {
            guard period == event.period else { return nil }
            let latest = events.filter { $0.period == period && $0.kind != .periodEnd }.map(\.time).max() ?? 0
            return latest...Self.maxEventTime
        }
        guard playedPeriods.contains(period) else { return nil }
        let end = events.first { $0.period == period && $0.kind == .periodEnd }?.time
        return 0...(end ?? Self.maxEventTime)
    }

    /// Moves event `id` to `time` seconds into `period`, within
    /// `timeLimits(for:in:)`. Returns `false`, changing nothing, otherwise.
    /// Order and scores follow, since both are computed from times.
    @discardableResult
    public mutating func updateTime(_ id: EventID, period: MatchPeriod, time: Int) -> Bool {
        guard let limits = timeLimits(for: id, in: period), limits.contains(time),
              let index = events.firstIndex(where: { $0.id == id })
        else { return false }
        events[index].period = period
        events[index].time = time
        return true
    }
}
