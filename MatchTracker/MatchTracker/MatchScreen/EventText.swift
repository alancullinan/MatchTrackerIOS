import MatchCore

/// How an event is described in a line of text, e.g. on the match screen's
/// last-event card. Kept out of the view so it can be tested.
enum EventText {
    /// "Point · Na Fianna · No. 11 Seán Ryan", "End of 1st Half".
    static func title(_ event: MatchEvent, in match: Match) -> String {
        var parts: [String]
        switch event.kind {
        case .shot(_, _, let outcome, _): parts = [outcome.displayName]
        case .foul: parts = ["Foul"]
        case .card(_, _, let card): parts = [cardName(card)]
        case .kickout(_, _, let won): parts = [won ? "Kickout won" : "Kickout lost"]
        case .substitution: parts = ["Substitution"]
        case .note: parts = ["Note"]
        case .periodEnd: return "End of \(event.period.displayName)"
        }
        if let side = event.side {
            parts.append(teamName(match[side]))
        }
        if let player = player(of: event, in: match) {
            parts.append(playerName(player))
        }
        return parts.joined(separator: " · ")
    }

    /// "2nd Half · 23' · 1-05 v 0-03": when, and the score straight after it.
    static func detail(_ event: MatchEvent, in match: Match) -> String {
        let minute = event.kind == .periodEnd ? MatchClock.text(seconds: event.time) : "\(event.minute)'"
        var parts = [event.period.displayName, minute]
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

    private static func player(of event: MatchEvent, in match: Match) -> Player? {
        guard let side = event.side else { return nil }
        let id: PlayerID?
        switch event.kind {
        case .shot(_, let player, _, _), .foul(_, let player, _, _), .card(_, let player, _), .kickout(_, let player, _):
            id = player
        case .substitution(_, _, let on):
            id = on
        case .note, .periodEnd:
            id = nil
        }
        return id.flatMap { match[side].player($0) }
    }

    private static func cardName(_ card: CardType) -> String {
        switch card {
        case .yellow: "Yellow card"
        case .red: "Red card"
        case .black: "Black card"
        }
    }
}
