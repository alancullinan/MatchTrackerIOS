import Foundation

/// The match clock. Running time is always derived from the wall clock
/// (`runningSince`), never counted by a timer, so it stays right while the app
/// is suspended and a Live Activity can show it.
public struct MatchClock: Hashable, Sendable, Codable {
    public var period: MatchPeriod
    /// Seconds played in `period` up to the last pause.
    public var bankedSeconds: Int
    /// When the clock was last started; `nil` while paused.
    public var runningSince: Date?

    public init(period: MatchPeriod = .notStarted, bankedSeconds: Int = 0, runningSince: Date? = nil) {
        self.period = period
        self.bankedSeconds = bankedSeconds
        self.runningSince = runningSince
    }

    public var isRunning: Bool { runningSince != nil }

    /// Whole seconds into `period` at `now`. Never less than `bankedSeconds`,
    /// even if `runningSince` is in the future (e.g. after a device clock change).
    public func elapsed(at now: Date) -> Int {
        guard let runningSince else { return bankedSeconds }
        let running = max(0, now.timeIntervalSince(runningSince))
        return bankedSeconds + Int(running.rounded(.down))
    }

    /// Starting a clock that is already running changes nothing.
    public mutating func start(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// Banks the running time. Pausing a clock that is already paused changes nothing.
    public mutating func pause(at now: Date) {
        guard runningSince != nil else { return }
        bankedSeconds = elapsed(at: now)
        runningSince = nil
    }
}
