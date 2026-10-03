import Foundation
import MatchCore
import Testing
@testable import MatchTracker

@MainActor
struct StatsTableTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// A started match with `kinds` recorded a minute apart in the 1st half.
    private func match(_ kinds: [MatchEvent.Kind], type: MatchType = .football) -> Match {
        var match = Match.new(matchType: type, team1Name: "Na Fianna", team2Name: "Cuala", date: t0)
        match.start(at: t0)
        for (index, kind) in kinds.enumerated() { match.record(kind, at: at(Double(index + 1) * 60)) }
        return match
    }

    private func row(_ table: StatsTable, _ label: String) -> StatsTable.Row? {
        table.sections.flatMap(\.rows).first { $0.label == label }
    }

    @Test func scoringShowsTheScoreAndItsParts() throws {
        let m = match([
            .shot(side: .team1, player: nil, outcome: .goal, type: .fromPlay),
            .shot(side: .team1, player: nil, outcome: .twoPointer, type: .fromPlay),
            .shot(side: .team2, player: nil, outcome: .point, type: .free),
        ])
        let table = StatsTable(match: m, period: nil)
        #expect(try #require(row(table, "Score")) == .init(label: "Score", team1: "1-02 (5)", team2: "0-01 (1)"))
        #expect(row(table, "2-Pointers")?.team1 == "1")
        #expect(row(table, "Points")?.team2 == "1")
    }

    @Test func hurlingHasNoTwoPointersAndNoBlackCardInCamogie() {
        #expect(row(StatsTable(match: match([], type: .hurling), period: nil), "2-Pointers") == nil)
        #expect(row(StatsTable(match: match([], type: .hurling), period: nil), "Black cards") != nil)
        #expect(row(StatsTable(match: match([], type: .camogie), period: nil), "Black cards") == nil)
    }

    @Test func accuracyIsADashWithNoShots() {
        let table = StatsTable(match: match([.shot(side: .team1, player: nil, outcome: .wide, type: .fromPlay),
                                             .shot(side: .team1, player: nil, outcome: .point, type: .fromPlay),
                                             .shot(side: .team1, player: nil, outcome: .point, type: .fromPlay)]), period: nil)
        #expect(row(table, "Accuracy") == .init(label: "Accuracy", team1: "67%", team2: "–"))
    }

    @Test func rareMissesShowOnlyWhenThereAreSome() {
        let none = StatsTable(match: match([]), period: nil)
        #expect(row(none, "Saved") == nil)
        #expect(row(none, "Wides") != nil)
        let saved = StatsTable(match: match([.shot(side: .team2, player: nil, outcome: .saved, type: .penalty)]), period: nil)
        #expect(row(saved, "Saved") == .init(label: "Saved", team1: "0", team2: "1"))
    }

    @Test func kickoutsAndDisciplineAreCounted() {
        let table = StatsTable(match: match([
            .kickout(side: .team1, player: nil, won: true),
            .kickout(side: .team1, player: nil, won: false),
            .foul(side: .team2, player: nil, outcome: .free, card: .yellow),
        ]), period: nil)
        #expect(row(table, "Retained")?.team1 == "50%")
        #expect(row(table, "Fouls conceded")?.team2 == "1")
        #expect(row(table, "Yellow cards")?.team2 == "1")
    }

    @Test func shootersShowNameScoreAndHowTheyScored() throws {
        var m = match([])
        var players = m.team1.players
        players[10].name = "Seán Ryan"
        m.updateRoster(.team1, players: players)
        let ryan = players[10].id
        for (outcome, type) in [(ShotOutcome.goal, ShotType.penalty), (.point, .free), (.point, .fromPlay), (.wide, .free)] {
            m.record(.shot(side: .team1, player: ryan, outcome: outcome, type: type), at: at(600))
        }
        m.record(.shot(side: .team1, player: nil, outcome: .wide, type: .fromPlay), at: at(700))

        let shooters = StatsTable(match: m, period: nil).team1Scorers
        #expect(shooters.count == 2)
        let first = try #require(shooters.first)
        #expect(first.name == "No. 11 Seán Ryan")
        #expect(first.score == "1-02 (5)")
        #expect(first.detail == "From play 0-01 · Free 0-01 · Penalty 1-00 · 3 of 4 shots")
        #expect(shooters.last?.name == "No player recorded")
        #expect(shooters.last?.detail == "0 of 1 shot")
    }

    @Test func aPeriodShowsOnlyItsOwnEvents() {
        var m = match([.shot(side: .team1, player: nil, outcome: .goal, type: .fromPlay)])
        m.endPeriod(at: at(1800))
        m.start(at: at(2400))
        m.record(.shot(side: .team1, player: nil, outcome: .point, type: .fromPlay), at: at(2500))
        #expect(row(StatsTable(match: m, period: .firstHalf), "Score")?.team1 == "1-00 (3)")
        #expect(row(StatsTable(match: m, period: .secondHalf), "Score")?.team1 == "0-01 (1)")
        #expect(row(StatsTable(match: m, period: nil), "Score")?.team1 == "1-01 (4)")
    }
}
