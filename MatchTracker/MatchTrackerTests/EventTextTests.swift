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
        #expect(EventText.detail(event, in: match) == "1st Half · 23 mins · 0-01 v 0-00")
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

    @Test func aFoulNamesItsCard() throws {
        var match = Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "Cuala", date: t0)
        match.start(at: t0)
        let foulRecorded = match.record(.foul(side: .team2, player: match.team2.players[3].id, outcome: .free, card: .black), at: t0)
        let foul = try #require(foulRecorded)
        let penaltyRecorded = match.record(.foul(side: .team1, player: nil, outcome: .penalty, card: nil), at: t0)
        let penalty = try #require(penaltyRecorded)

        #expect(EventText.title(foul, in: match) == "Foul, black card · Cuala · No. 4")
        #expect(EventText.title(penalty, in: match) == "Penalty conceded · Na Fianna")
    }

    @Test func aSubstitutionNamesBothPlayers() throws {
        var match = Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "Cuala", date: t0)
        match.team1.players[17].name = "Ciara Byrne"
        match.start(at: t0)
        let off = match.team1.players[10].id
        let on = match.team1.players[17].id
        let bothRecorded = match.record(.substitution(side: .team1, off: off, on: on), at: t0)
        let both = try #require(bothRecorded)
        let onlyOnRecorded = match.record(.substitution(side: .team1, off: nil, on: on), at: t0)
        let onlyOn = try #require(onlyOnRecorded)
        let neitherRecorded = match.record(.substitution(side: .team1, off: nil, on: nil), at: t0)
        let neither = try #require(neitherRecorded)

        #expect(EventText.title(both, in: match) == "Substitution · Na Fianna · No. 18 Ciara Byrne on for No. 11")
        #expect(EventText.title(onlyOn, in: match) == "Substitution · Na Fianna · No. 18 Ciara Byrne on")
        #expect(EventText.title(neither, in: match) == "Substitution · Na Fianna")
    }

    @Test func aNoteShowsItsText() throws {
        var match = Match.new(matchType: .hurling, team1Name: "A", team2Name: "B", date: t0)
        match.start(at: t0)
        let noteRecorded = match.record(.note(side: nil), note: "Rain starting", at: t0)
        let note = try #require(noteRecorded)
        let emptyRecorded = match.record(.note(side: .team2), at: t0)
        let empty = try #require(emptyRecorded)

        #expect(EventText.title(note, in: match) == "Rain starting")
        #expect(EventText.title(empty, in: match) == "Note · B")
    }
}
