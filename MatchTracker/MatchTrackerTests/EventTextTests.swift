import Foundation
import MatchCore
import Testing
@testable import MatchTracker

struct EventTextTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func aScoreNamesTheTeamAndPlayer() throws {
        var match = Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "Cuala", date: t0)
        match.team1.players[10].name = "Seán Ryan"
        match.start(at: t0)
        let recorded = match.record(.shot(side: .team1, player: match.team1.players[10].id, outcome: .point, type: .free),
                                    at: t0.addingTimeInterval(22 * 60 + 5))
        let event = try #require(recorded)

        #expect(EventText.title(event, in: match) == "Point · Na Fianna · No. 11 Seán Ryan")
        #expect(EventText.detail(event, in: match) == "1st Half · 23' · 0-01 v 0-00")
    }

    @Test func anUnnamedPlayerShowsTheirNumber() {
        let player = Player(jerseyNumber: 7)
        #expect(EventText.playerName(player) == "No. 7")
    }

    @Test func aPeriodEndShowsWhenItEnded() throws {
        var match = Match.new(matchType: .hurling, team1Name: "A", team2Name: "B", date: t0)
        match.start(at: t0)
        match.endPeriod(at: t0.addingTimeInterval(31 * 60 + 40))
        let end = try #require(match.events.last)

        #expect(EventText.title(end, in: match) == "End of 1st Half")
        #expect(EventText.detail(end, in: match) == "1st Half · 31:40 · 0-00 v 0-00")
    }

    @Test func namesSplitIntoFirstNameAndSurname() {
        #expect(EventText.nameLines(Player(jerseyNumber: 1, name: "Aoife Casey")) == ("Aoife", "Casey"))
        #expect(EventText.nameLines(Player(jerseyNumber: 1, name: "Seán Mac Cumhaill")) == ("Seán", "Mac Cumhaill"))
        #expect(EventText.nameLines(Player(jerseyNumber: 1, name: "Cha")) == ("Cha", nil))
        #expect(EventText.nameLines(Player(jerseyNumber: 1)) == (nil, nil))
    }
}
