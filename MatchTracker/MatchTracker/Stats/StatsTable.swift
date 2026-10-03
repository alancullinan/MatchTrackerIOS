import Foundation
import MatchCore

/// The statistics screen's content as text, side by side for the two teams,
/// kept out of the view so it can be tested. The numbers come from
/// `MatchCore`'s `TeamStats`; this only chooses rows and formats them.
@MainActor
struct StatsTable: Equatable {
    struct Row: Equatable, Identifiable {
        let label: String
        let team1: String
        let team2: String
        var id: String { label }
    }

    struct Section: Equatable, Identifiable {
        let title: String
        let rows: [Row]
        var id: String { title }
    }

    /// One scorer, or the shots recorded without a player.
    struct Scorer: Equatable, Identifiable {
        let id: String
        let name: String
        /// "1-02 (5)".
        let score: String
        /// "From play 0-01 · Free 1-01 · 4 of 6 shots".
        let detail: String
    }

    let sections: [Section]
    let team1Scorers: [Scorer]
    let team2Scorers: [Scorer]

    /// The table for `match`, for one period or the whole match (`nil`).
    init(match: Match, period: MatchPeriod?) {
        let one = match.stats(.team1, period: period)
        let two = match.stats(.team2, period: period)
        let type = match.matchType

        func row(_ label: String, _ value: (TeamStats) -> String) -> Row {
            Row(label: label, team1: value(one), team2: value(two))
        }
        func count(_ label: String, _ value: (TeamStats) -> Int) -> Row {
            row(label) { "\(value($0))" }
        }
        /// A count shown only when either team has one, to keep the table short.
        func optional(_ label: String, _ value: (TeamStats) -> Int) -> Row? {
            value(one) == 0 && value(two) == 0 ? nil : count(label, value)
        }

        var scoring = [
            row("Score") { Self.scoreText($0.score) },
            count("Goals") { $0.score.goals },
            count("Points") { $0.shooting[.point] },
        ]
        if type.allowsTwoPointers {
            scoring.append(count("2-Pointers") { $0.shooting[.twoPointer] })
        }

        let shooting = [
            count("Shots") { $0.shooting.shots },
            row("Accuracy") { Self.percent($0.shooting.accuracy) },
            count("Wides") { $0.shooting[.wide] },
            optional("Saved") { $0.shooting[.saved] },
            optional("Dropped short") { $0.shooting[.droppedShort] },
            optional("Off the post") { $0.shooting[.offPost] },
        ].compactMap(\.self)

        let kickouts = [
            count("Won") { $0.kickoutsWon },
            count("Lost") { $0.kickoutsLost },
            row("Retained") { Self.percent($0.kickoutRetention) },
        ]

        let discipline = [count("Fouls conceded") { $0.fouls }]
            + CardType.options(for: type).map { card in count("\(card.displayName) cards") { $0.cards[card, default: 0] } }
            + [count("Substitutions") { $0.substitutions }]

        sections = [
            Section(title: "Scoring", rows: scoring),
            Section(title: "Shooting", rows: shooting),
            Section(title: "Own Kickouts", rows: kickouts),
            Section(title: "Fouls, Cards and Subs", rows: discipline),
        ]
        team1Scorers = Self.scorers(one, team: match.team1, matchType: type)
        team2Scorers = Self.scorers(two, team: match.team2, matchType: type)
    }

    /// "1-05 (8)".
    static func scoreText(_ score: Score) -> String {
        "\(score) (\(score.total))"
    }

    /// "62%", or "–" when there is nothing to divide.
    static func percent(_ fraction: Double?) -> String {
        guard let fraction else { return "–" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    /// Everyone who took a shot, in `TeamStats`' order (by score, then
    /// number), with the shots recorded without a player last.
    static func scorers(_ stats: TeamStats, team: Team, matchType: MatchType) -> [Scorer] {
        stats.players.map { player in
            let name = player.player.flatMap(team.player).map(EventText.playerName) ?? "No player recorded"
            let byType = ShotType.options(for: matchType).compactMap { type in
                player.scoreByShotType[type].map { "\(type.displayName) \($0)" }
            }
            let shots = "\(player.shooting.scored) of \(player.shooting.shots) \(player.shooting.shots == 1 ? "shot" : "shots")"
            return Scorer(
                id: player.player?.description ?? "none",
                name: name,
                score: scoreText(player.score),
                detail: (byType + [shots]).joined(separator: " · ")
            )
        }
    }
}
