import MatchCore

/// How an event is described in a line of text, e.g. on the match screen's
/// last-event card. Kept out of the view so it can be tested.
enum EventText {
    /// "Point · Na Fianna · No. 11 Seán Ryan", "End of 1st Half". A note
    /// shows its text.
    static func title(_ event: MatchEvent, in match: Match) -> String {
        var parts: [String]
        switch event.kind {
        case .shot(_, _, let outcome, _): parts = [outcome.displayName]
        case .foul(_, _, let outcome, let card): parts = [foulName(outcome, card: card)]
        case .card(_, _, let card): parts = [cardName(card)]
        case .kickout(_, _, let won): parts = [won ? "Kickout won" : "Kickout lost"]
        case .substitution: parts = ["Substitution"]
        case .note: parts = [event.note ?? "Note"]
        case .periodEnd: return "End of \(event.period.displayName)"
        }
        if let side = event.side {
            parts.append(teamName(match[side]))
        }
        if let players = players(of: event, in: match) {
            parts.append(players)
        }
        return parts.joined(separator: " · ")
    }

    /// "Foul", "Penalty conceded", "Foul, black card".
    static func foulName(_ outcome: FoulOutcome, card: CardType?) -> String {
        let name = outcome == .penalty ? "Penalty conceded" : "Foul"
        return card.map { "\(name), \(cardName($0).lowercased())" } ?? name
    }

    static func cardName(_ card: CardType) -> String {
        "\(card.displayName) card"
    }

    /// "2nd Half · 23' · 1-05 v 0-03": when, and the score straight after it.
    /// Without the period where it is already shown, e.g. under a period heading.
    static func detail(_ event: MatchEvent, in match: Match, showsPeriod: Bool = true) -> String {
        let minute = event.kind == .periodEnd ? MatchClock.text(seconds: event.time) : "\(event.minute)'"
        var parts = showsPeriod ? [event.period.displayName, minute] : [minute]
        if let team1 = match.score(.team1, through: event.id), let team2 = match.score(.team2, through: event.id) {
            parts.append("\(team1) v \(team2)")
        }
        return parts.joined(separator: " · ")
    }

    /// "No. 11 Seán Ryan", or "No. 11" for an unnamed player.
    static func playerName(_ player: Player) -> String {
        guard let name = player.name else { return "No. \(player.jerseyNumber)" }
        return "No. \(player.jerseyNumber) \(name)"
    }

    /// A name split for the team sheet: first name, then the rest as the
    /// surname ("Seán", "Mac Cumhaill"). Both `nil` for an unnamed player.
    static func nameLines(_ player: Player) -> (first: String?, surname: String?) {
        guard let name = player.name else { return (nil, nil) }
        let parts = name.split(separator: " ", maxSplits: 1)
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : nil)
    }

    static func teamName(_ team: Team) -> String {
        team.name.isEmpty ? "Unnamed team" : team.name
    }

    /// The player an event names, or for a substitution "No. 18 on for No. 11".
    private static func players(of event: MatchEvent, in match: Match) -> String? {
        guard let side = event.side else { return nil }
        let team = match[side]
        func name(_ id: PlayerID?) -> String? { id.flatMap(team.player).map(playerName) }
        switch event.kind {
        case .shot(_, let player, _, _), .foul(_, let player, _, _), .card(_, let player, _), .kickout(_, let player, _):
            return name(player)
        case .substitution(_, let off, let on):
            switch (name(off), name(on)) {
            case let (off?, on?): return "\(on) on for \(off)"
            case let (off?, nil): return "\(off) off"
            case let (nil, on?): return "\(on) on"
            case (nil, nil): return nil
            }
        case .note, .periodEnd:
            return nil
        }
    }
}
