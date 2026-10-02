/// A team's score: goals (3 each) and points.
public struct Score: Hashable, Sendable, CustomStringConvertible {
    public var goals: Int
    /// Points as a scoreboard shows them: a two-pointer adds 2.
    public var points: Int
    /// How many of the points came from two-pointers (for stats; already counted in `points`).
    public var twoPointers: Int

    public init(goals: Int = 0, points: Int = 0, twoPointers: Int = 0) {
        self.goals = goals
        self.points = points
        self.twoPointers = twoPointers
    }

    /// The score from `side`'s shots among `events`. Misses and other event types don't count.
    public init<Events: Sequence>(of side: TeamSide, in events: Events) where Events.Element == MatchEvent {
        self.init()
        for event in events {
            if case .shot(side, _, let outcome, _) = event.kind {
                add(outcome)
            }
        }
    }

    public var total: Int { goals * 3 + points }

    public mutating func add(_ outcome: ShotOutcome) {
        switch outcome {
        case .goal:
            goals += 1
        case .point:
            points += 1
        case .twoPointer:
            points += 2
            twoPointers += 1
        case .wide, .saved, .droppedShort, .offPost:
            break
        }
    }

    /// "1-05": goals, then points padded to two digits.
    public var description: String {
        points < 10 ? "\(goals)-0\(points)" : "\(goals)-\(points)"
    }
}

extension Match {
    public func score(_ side: TeamSide) -> Score {
        Score(of: side, in: events)
    }
}

extension MatchType {
    /// Two-pointers exist in Football and Ladies Football, not Hurling or Camogie.
    public var allowsTwoPointers: Bool {
        switch self {
        case .football, .ladiesFootball: true
        case .hurling, .camogie: false
        }
    }
}
