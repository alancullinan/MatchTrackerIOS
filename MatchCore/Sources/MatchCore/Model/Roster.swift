import Foundation

extension Team {
    /// The player who would be added next (the next jersey number), or `nil`
    /// once the team has `maxRosterSize` players.
    public func nextExtraPlayer() -> Player? {
        guard players.count < Self.maxRosterSize else { return nil }
        return Player(jerseyNumber: players.count + 1)
    }
}

extension Match {
    /// Whether any event names `id` (as the player, or either player in a substitution).
    public func isReferenced(_ id: PlayerID) -> Bool {
        events.contains { event in
            switch event.kind {
            case .shot(_, let player, _, _), .foul(_, let player, _, _), .card(_, let player, _), .kickout(_, let player, _):
                player == id
            case .substitution(_, let off, let on):
                off == id || on == id
            case .note, .periodEnd:
                false
            }
        }
    }

    /// Replaces `side`'s players with an edited roster: names changed, players
    /// added after the last number, or added players removed again. Returns
    /// `false`, changing nothing, unless:
    /// - jersey numbers run 1, 2, 3 ... in order, at least `startingRosterSize`
    ///   and at most `maxRosterSize` of them;
    /// - every player kept has the same id and number as before (ids are never
    ///   regenerated; events refer to them);
    /// - any player left out is an added one (above `startingRosterSize`) that no event names.
    /// Names are cleaned: blank becomes `nil`.
    @discardableResult
    public mutating func updateRoster(_ side: TeamSide, players: [Player]) -> Bool {
        let current = self[side].players
        guard (Team.startingRosterSize...Team.maxRosterSize).contains(players.count),
              players.map(\.jerseyNumber) == Array(1...players.count)
        else { return false }
        for player in players {
            if let existing = current.first(where: { $0.id == player.id }) {
                guard existing.jerseyNumber == player.jerseyNumber else { return false }
            } else {
                // A new player can only be one added above the starting numbers.
                guard player.jerseyNumber > Team.startingRosterSize,
                      !current.contains(where: { $0.jerseyNumber == player.jerseyNumber })
                else { return false }
            }
        }
        let kept = Set(players.map(\.id))
        for removed in current where !kept.contains(removed.id) {
            guard removed.jerseyNumber > Team.startingRosterSize, !isReferenced(removed.id) else { return false }
        }
        self[side].players = players.map { Player(id: $0.id, jerseyNumber: $0.jerseyNumber, name: $0.name) }
        return true
    }
}
