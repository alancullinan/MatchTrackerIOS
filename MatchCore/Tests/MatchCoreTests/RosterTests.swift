import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func newMatch() -> Match {
    Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: t0)
}

/// `side`'s players with `extra` more added after the last number.
private func withExtras(_ match: Match, _ side: TeamSide = .team1, _ extra: Int) -> [Player] {
    var players = match[side].players
    for _ in 0..<extra {
        players.append(Player(jerseyNumber: players.count + 1))
    }
    return players
}

// #expect can't call a mutating method itself, so each step's result is kept first.

@Test func aTeamStartsWith30AndCanGrowTo40() {
    let match = newMatch()
    #expect(match.team1.players.count == 30)
    #expect(match.team1.nextExtraPlayer()?.jerseyNumber == 31)

    var full = match.team1
    full.players = withExtras(match, .team1, 10)
    #expect(full.nextExtraPlayer() == nil)
}

@Test func playersCanBeNamedWithoutChangingTheirIDs() throws {
    var match = newMatch()
    var players = match.team1.players
    players[10].name = "  Seán Ryan "
    let ids = players.map(\.id)

    let updated = match.updateRoster(.team1, players: players)
    #expect(updated)
    #expect(match.team1.players[10].name == "Seán Ryan")
    #expect(match.team1.players.map(\.id) == ids)
}

@Test func playersCanBeAddedUpTo40() {
    var match = newMatch()
    let added = match.updateRoster(.team2, players: withExtras(match, .team2, 10))
    #expect(added)
    #expect(match.team2.players.map(\.jerseyNumber) == Array(1...40))

    let tooMany = match.updateRoster(.team2, players: withExtras(match, .team2, 1))
    #expect(!tooMany)
    #expect(match.team2.players.count == 40)
}

@Test func numbersMustRunInOrderWithoutGaps() {
    var match = newMatch()
    var players = match.team1.players
    players.append(Player(jerseyNumber: 32))

    let gap = match.updateRoster(.team1, players: players)
    #expect(!gap)
    #expect(match.team1.players.count == 30)
}

@Test func theFirst30CantBeRemovedOrReplaced() {
    var match = newMatch()
    let removed = match.updateRoster(.team1, players: Array(match.team1.players.dropLast()))
    #expect(!removed)

    var replaced = match.team1.players
    replaced[4] = Player(jerseyNumber: 5, name: "New id")
    let regenerated = match.updateRoster(.team1, players: replaced)
    #expect(!regenerated)
}

@Test func anAddedPlayerCanBeRemovedIfNoEventNamesThem() throws {
    var match = newMatch()
    match.updateRoster(.team1, players: withExtras(match, .team1, 2))
    let thirtyTwo = try #require(match.team1.player(jersey: 32))

    let removed = match.updateRoster(.team1, players: Array(match.team1.players.dropLast()))
    #expect(removed)
    #expect(match.team1.player(thirtyTwo.id) == nil)
}

@Test func anAddedPlayerNamedInAnEventCantBeRemoved() throws {
    var match = newMatch()
    match.updateRoster(.team1, players: withExtras(match, .team1, 1))
    let thirtyOne = try #require(match.team1.player(jersey: 31))
    match.start(at: t0)
    match.record(.substitution(side: .team1, off: match.team1.players[9].id, on: thirtyOne.id), at: t0)
    #expect(match.isReferenced(thirtyOne.id))

    let removed = match.updateRoster(.team1, players: Array(match.team1.players.dropLast()))
    #expect(!removed)
    #expect(match.team1.player(thirtyOne.id) != nil)
}
