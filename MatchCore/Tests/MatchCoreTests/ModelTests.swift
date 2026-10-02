import Foundation
import Testing
@testable import MatchCore

private func roundTrip<T: Codable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}

/// A whole-second date, so it survives JSON exactly.
private let kickOff = Date(timeIntervalSince1970: 1_754_800_000)

// MARK: - Ids

@Test func freshIDsDiffer() {
    #expect(MatchID() != MatchID())
}

@Test func idEncodesAsAPlainUUIDString() throws {
    let uuid = try #require(UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"))
    let data = try JSONEncoder().encode([PlayerID(uuid)])
    #expect(String(decoding: data, as: UTF8.self) == #"["E621E1F8-C36C-495A-93FC-0C247A3E6E5F"]"#)
    #expect(try JSONDecoder().decode([PlayerID].self, from: data) == [PlayerID(uuid)])
}

// MARK: - Players and teams

@Test func blankPlayerNamesBecomeNil() {
    #expect(Player(jerseyNumber: 1, name: "").name == nil)
    #expect(Player(jerseyNumber: 1, name: "  \n").name == nil)
    #expect(Player(jerseyNumber: 1, name: " Seán ").name == "Seán")
    #expect(PanelSlot(jerseyNumber: 1, name: " ").name == nil)
}

@Test func rosterHasThirtyUnnamedPlayers() {
    let team = Team.roster(name: "Team A")
    #expect(team.players.map(\.jerseyNumber) == Array(1...30))
    #expect(team.players.allSatisfy { $0.name == nil })
    #expect(Set(team.players.map(\.id)).count == 30)
    #expect(team.player(jersey: 7)?.jerseyNumber == 7)
    #expect(team.player(team.players[4].id)?.jerseyNumber == 5)
}

@Test func emptyPanelHasThirtyEmptySlots() {
    let panel = PlayerPanel.empty(name: "Seniors")
    #expect(panel.slots.map(\.jerseyNumber) == Array(1...30))
    #expect(panel.slots.allSatisfy { $0.name == nil })
}

// MARK: - Events

private let player = PlayerID()
private let substitute = PlayerID()

private let everyKind: [(MatchEvent.Kind, TeamSide?, EventType)] = [
    (.shot(side: .team1, player: player, outcome: .twoPointer, type: .free), .team1, .shot),
    (.shot(side: .team2, player: nil, outcome: .wide, type: .fromPlay), .team2, .shot),
    (.foul(side: .team2, player: player, outcome: .penalty, card: .black), .team2, .foul),
    (.foul(side: .team1, player: nil, outcome: .free, card: nil), .team1, .foul),
    (.card(side: .team1, player: player, card: .red), .team1, .card),
    (.kickout(side: .team2, player: nil, won: true), .team2, .kickout),
    (.substitution(side: .team1, off: player, on: substitute), .team1, .substitution),
    (.substitution(side: .team1, off: player, on: nil), .team1, .substitution),
    (.note(side: .team2), .team2, .note),
    (.note(side: nil), nil, .note),
    (.periodEnd, nil, .periodEnd),
]

@Test func everyEventKindRoundTrips() throws {
    for (kind, _, _) in everyKind {
        let event = MatchEvent(period: .secondHalf, time: 1234, note: "Blood sub", kind: kind)
        #expect(try roundTrip(event) == event)
    }
}

@Test func eventSideAndTypeMatchTheKind() {
    for (kind, side, type) in everyKind {
        let event = MatchEvent(period: .firstHalf, time: 0, kind: kind)
        #expect(event.side == side)
        #expect(event.type == type)
    }
}

// MARK: - Clock

@Test func elapsedIsDerivedFromTheWallClock() {
    let clock = MatchClock(period: .firstHalf, bankedSeconds: 300, runningSince: kickOff)
    #expect(clock.isRunning)
    #expect(clock.elapsed(at: kickOff.addingTimeInterval(90)) == 390)
    #expect(clock.elapsed(at: kickOff.addingTimeInterval(90.9)) == 390)
}

@Test func pausingBanksTheTime() {
    var clock = MatchClock(period: .firstHalf)
    clock.start(at: kickOff)
    clock.pause(at: kickOff.addingTimeInterval(125))
    #expect(!clock.isRunning)
    #expect(clock.bankedSeconds == 125)
    #expect(clock.elapsed(at: kickOff.addingTimeInterval(1000)) == 125)

    clock.start(at: kickOff.addingTimeInterval(200))
    #expect(clock.elapsed(at: kickOff.addingTimeInterval(260)) == 185)
}

@Test func pausingAPausedClockChangesNothing() {
    var clock = MatchClock(period: .firstHalf)
    clock.start(at: kickOff)
    clock.pause(at: kickOff.addingTimeInterval(60))
    clock.pause(at: kickOff.addingTimeInterval(500))
    #expect(clock == MatchClock(period: .firstHalf, bankedSeconds: 60))
}

@Test func startingARunningClockChangesNothing() {
    var clock = MatchClock(period: .firstHalf)
    clock.start(at: kickOff)
    clock.start(at: kickOff.addingTimeInterval(45))
    #expect(clock.runningSince == kickOff)
    #expect(clock.elapsed(at: kickOff.addingTimeInterval(100)) == 100)
}

@Test func aFutureStartGivesNoNegativeTime() {
    let clock = MatchClock(period: .firstHalf, bankedSeconds: 30, runningSince: kickOff.addingTimeInterval(60))
    #expect(clock.elapsed(at: kickOff) == 30)
}

// MARK: - Match

@Test func newMatchIsNotStartedWithTwoRosters() {
    let match = Match.new(matchType: .hurling, team1Name: "Team A", team2Name: "Team B", date: kickOff)
    #expect(match.clock == MatchClock())
    #expect(match.events.isEmpty)
    #expect(match.legacyID == nil)
    #expect(match[.team1].name == "Team A")
    #expect(match[.team2].players.count == 30)
}

@Test func matchRoundTrips() throws {
    var match = Match.new(matchType: .ladiesFootball, team1Name: "Team A", team2Name: "Team B", competition: "Junior C", date: kickOff)
    match.events.append(MatchEvent(period: .firstHalf, time: 61, kind: .shot(side: .team1, player: match.team1.players[10].id, outcome: .goal, type: .penalty)))
    match.clock.start(at: kickOff)
    #expect(try roundTrip(match) == match)
}

@Test func subscriptReadsAndWritesTheRightTeam() {
    var match = Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: kickOff)
    match[.team2].name = "Team C"
    #expect(match.team2.name == "Team C")
    #expect(match.team1.name == "Team A")
    #expect(TeamSide.team1.opponent == .team2)
}
