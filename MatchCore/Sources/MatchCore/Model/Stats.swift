/// How a set of shots went.
public struct ShootingStats: Hashable, Sendable {
    /// Shots by outcome; outcomes with no shots are absent.
    public var outcomes: [ShotOutcome: Int] = [:]

    public init() {}

    public var shots: Int { outcomes.values.reduce(0, +) }

    /// Shots that scored: goals, points and two-pointers.
    public var scored: Int { outcomes.filter { $0.key.scores }.values.reduce(0, +) }

    /// Shots that didn't score.
    public var missed: Int { shots - scored }

    /// Scored shots as a fraction of all shots (0...1); `nil` with no shots.
    public var accuracy: Double? {
        shots == 0 ? nil : Double(scored) / Double(shots)
    }

    public subscript(outcome: ShotOutcome) -> Int {
        outcomes[outcome, default: 0]
    }

    mutating func add(_ outcome: ShotOutcome) {
        outcomes[outcome, default: 0] += 1
    }
}

extension ShotOutcome {
    /// Goals, points and two-pointers score; wides, saves, drops and the post don't.
    public var scores: Bool {
        switch self {
        case .goal, .point, .twoPointer: true
        case .wide, .saved, .droppedShort, .offPost: false
        }
    }
}

/// One player's shooting and scoring. `player` is `nil` for shots recorded without a player.
public struct PlayerStats: Hashable, Sendable {
    public var player: PlayerID?
    public var score = Score()
    public var shooting = ShootingStats()
    /// Score by shot type (frees, penalties, 45s, ...); types with no score are absent.
    public var scoreByShotType: [ShotType: Score] = [:]

    public init(player: PlayerID?) {
        self.player = player
    }

    mutating func add(_ outcome: ShotOutcome, type: ShotType) {
        shooting.add(outcome)
        score.add(outcome)
        if outcome.scores {
            scoreByShotType[type, default: Score()].add(outcome)
        }
    }
}

/// A team's statistics, from a set of events.
public struct TeamStats: Hashable, Sendable {
    public var score = Score()
    public var shooting = ShootingStats()
    /// Every player who took a shot, highest score first, then by jersey number.
    /// Shots without a player are grouped last, under `player == nil`.
    public var players: [PlayerStats] = []
    /// Fouls conceded.
    public var fouls = 0
    /// Cards shown, whether recorded with a foul or on their own.
    public var cards: [CardType: Int] = [:]
    public var substitutions = 0
    /// The team's own kickouts, won and lost.
    public var kickoutsWon = 0
    public var kickoutsLost = 0

    /// Own kickouts won as a fraction of all taken (0...1); `nil` with none.
    public var kickoutRetention: Double? {
        let taken = kickoutsWon + kickoutsLost
        return taken == 0 ? nil : Double(kickoutsWon) / Double(taken)
    }

    /// Statistics for `side` from `events` - a whole match, or a filtered part
    /// such as one period. Pass `team` to order players with the same score by
    /// jersey number.
    public init<Events: Sequence>(of side: TeamSide, in events: Events, team: Team? = nil) where Events.Element == MatchEvent {
        var byPlayer: [PlayerID?: PlayerStats] = [:]
        for event in events where event.side == side {
            switch event.kind {
            case .shot(_, let player, let outcome, let type):
                score.add(outcome)
                shooting.add(outcome)
                byPlayer[player, default: PlayerStats(player: player)].add(outcome, type: type)
            case .foul(_, _, _, let card):
                fouls += 1
                if let card { cards[card, default: 0] += 1 }
            case .card(_, _, let card):
                cards[card, default: 0] += 1
            case .substitution:
                substitutions += 1
            case .kickout(_, _, let won):
                if won { kickoutsWon += 1 } else { kickoutsLost += 1 }
            case .note, .periodEnd:
                break
            }
        }

        let jersey = { (id: PlayerID?) -> Int in
            id.flatMap { team?.player($0)?.jerseyNumber } ?? Int.max
        }
        players = byPlayer.values.sorted { a, b in
            if (a.player == nil) != (b.player == nil) { return b.player == nil }
            if a.score.total != b.score.total { return a.score.total > b.score.total }
            if jersey(a.player) != jersey(b.player) { return jersey(a.player) < jersey(b.player) }
            return (a.player?.description ?? "") < (b.player?.description ?? "")
        }
    }

    /// Players who scored, in the same order as `players`.
    public var scorers: [PlayerStats] {
        players.filter { $0.score.total > 0 }
    }
}

extension Match {
    /// A team's statistics for the whole match.
    public func stats(_ side: TeamSide) -> TeamStats {
        TeamStats(of: side, in: events, team: self[side])
    }

    /// A team's statistics for one period, or the whole match with `nil`.
    public func stats(_ side: TeamSide, period: MatchPeriod?) -> TeamStats {
        guard let period else { return stats(side) }
        return TeamStats(of: side, in: events.filter { $0.period == period }, team: self[side])
    }
}
