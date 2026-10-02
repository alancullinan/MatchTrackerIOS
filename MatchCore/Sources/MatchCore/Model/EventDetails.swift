import Foundation

// Filling in the details of fouls, kickouts, substitutions and notes after
// they are recorded, as `updateShot` does for shots. Each keeps the event's
// team, period and time, and returns `false`, changing nothing, if the event
// is of another kind or a detail doesn't fit.

extension CardType {
    /// The cards in the order they are offered: yellow, black, red.
    public static let offered: [CardType] = [.yellow, .black, .red]

    /// The name to show.
    public var displayName: String {
        switch self {
        case .yellow: "Yellow"
        case .red: "Red"
        case .black: "Black"
        }
    }
}

extension FoulOutcome {
    /// The name to show.
    public var displayName: String {
        switch self {
        case .free: "Free"
        case .penalty: "Penalty"
        }
    }
}

extension MatchEvent {
    /// A note as stored: trimmed, and `nil` when blank.
    static func cleanNote(_ note: String?) -> String? {
        note.flatMap { text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

extension Match {
    /// Sets a recorded foul's outcome, card, player (one of that team's, or
    /// `nil`) and note (blank becomes `nil`).
    @discardableResult
    public mutating func updateFoul(
        _ id: EventID,
        outcome: FoulOutcome,
        card: CardType?,
        player: PlayerID?,
        note: String?
    ) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }),
              case .foul(let side, _, _, _) = events[index].kind,
              isPlayer(player, on: side)
        else { return false }
        events[index].kind = .foul(side: side, player: player, outcome: outcome, card: card)
        events[index].note = MatchEvent.cleanNote(note)
        return true
    }

    /// Sets whether a recorded kickout was won, who won it (one of that team's,
    /// or `nil`) and its note (blank becomes `nil`).
    @discardableResult
    public mutating func updateKickout(_ id: EventID, won: Bool, player: PlayerID?, note: String?) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }),
              case .kickout(let side, _, _) = events[index].kind,
              isPlayer(player, on: side)
        else { return false }
        events[index].kind = .kickout(side: side, player: player, won: won)
        events[index].note = MatchEvent.cleanNote(note)
        return true
    }

    /// Sets who came off and who came on (each one of that team's, or `nil`;
    /// never the same player) and the note (blank becomes `nil`).
    @discardableResult
    public mutating func updateSubstitution(_ id: EventID, off: PlayerID?, on: PlayerID?, note: String?) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }),
              case .substitution(let side, _, _) = events[index].kind,
              isPlayer(off, on: side), isPlayer(on, on: side),
              off == nil || off != on
        else { return false }
        events[index].kind = .substitution(side: side, off: off, on: on)
        events[index].note = MatchEvent.cleanNote(note)
        return true
    }

    /// Sets a note's text. A note is its text, so blank text returns `false`
    /// and changes nothing; delete the note instead.
    @discardableResult
    public mutating func updateNote(_ id: EventID, text: String) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }),
              case .note = events[index].kind,
              let text = MatchEvent.cleanNote(text)
        else { return false }
        events[index].note = text
        return true
    }

    /// `true` for `nil` (no player picked) or a player on `side`'s team.
    private func isPlayer(_ id: PlayerID?, on side: TeamSide) -> Bool {
        id.map { self[side].player($0) != nil } ?? true
    }
}
