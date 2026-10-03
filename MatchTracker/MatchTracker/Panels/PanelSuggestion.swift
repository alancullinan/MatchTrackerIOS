import Foundation
import MatchCore

/// Which panel to offer first when importing into a team: the one last
/// imported into this team, or else the one last imported into a team of the
/// same name in the most recent other match ("Na Fianna" gets Na Fianna's panel
/// again next week).
enum PanelSuggestion {
    /// A team in another match, from the stored columns, so nothing is decoded.
    struct PastTeam: Equatable {
        let date: Date
        let name: String
        let lastPanelID: PanelID?
    }

    /// The panel to suggest for `team`, if it still exists (is in `panels`).
    static func suggested(for team: Team, pastTeams: [PastTeam], panels: Set<PanelID>) -> PanelID? {
        if let last = team.lastPanelID, panels.contains(last) { return last }
        return pastTeams
            .filter { sameName($0.name, team.name) }
            .sorted { $0.date > $1.date }
            .lazy
            .compactMap(\.lastPanelID)
            .first { panels.contains($0) }
    }

    /// Both teams of every stored match except `matchID`.
    static func pastTeams(_ stored: [StoredMatch], excluding matchID: MatchID) -> [PastTeam] {
        stored.filter { $0.id != matchID.uuid }.flatMap { match in
            [PastTeam(date: match.date, name: match.team1Name, lastPanelID: match.team1LastPanelID.map(PanelID.init)),
             PastTeam(date: match.date, name: match.team2Name, lastPanelID: match.team2LastPanelID.map(PanelID.init))]
        }
    }

    /// Names match ignoring case, accents and surrounding spaces ("Sean" is "Seán").
    static func sameName(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces)
            .compare(b.trimmingCharacters(in: .whitespaces), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
