import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func details(_ team1: String = "Na Fianna", _ team2: String = "Cuala", type: MatchType = .football) -> MatchDetails {
    MatchDetails(matchType: type, team1Name: team1, team2Name: team2, competition: "League", date: t0,
                 venue: "Mobhi Road", referee: "J. Murphy")
}

private let point = MatchEvent.Kind.shot(side: .team1, player: nil, outcome: .point, type: .fromPlay)

// #expect can't call a mutating method itself, so each step's result is kept first.

@Test func aNewMatchHasTheDetailsGiven() throws {
    let match = try #require(Match.new(details()))
    #expect(match.details == details())
    #expect(match.clock.period == .notStarted)
    #expect(match.team1.players.count == Team.startingRosterSize)
    #expect(match.team2.players.count == Team.startingRosterSize)
}

@Test func bothTeamsMustBeNamed() {
    #expect(details().isComplete)
    #expect(!details("", "Cuala").isComplete)
    #expect(!details("Na Fianna", "   ").isComplete)
    #expect(Match.new(details("", "Cuala")) == nil)
}

@Test func surroundingSpacesAreRemoved() throws {
    var spaced = details("  Na Fianna ", "Cuala\n")
    spaced.competition = " League "
    spaced.venue = "  "
    let match = try #require(Match.new(spaced))
    #expect(match.team1.name == "Na Fianna")
    #expect(match.team2.name == "Cuala")
    #expect(match.competition == "League")
    #expect(match.venue == "")
}

@Test func editingKeepsPlayersEventsAndClock() throws {
    var match = try #require(Match.new(details()))
    match.start(at: t0)
    match.record(point, at: t0.addingTimeInterval(60))
    let before = match

    var edited = match.details
    edited.team1Name = "Na Fianna CLG"
    edited.venue = "Croke Park"
    let applied = match.apply(edited)

    #expect(applied)
    #expect(match.details == edited)
    #expect(match.team1.players == before.team1.players)
    #expect(match.events == before.events)
    #expect(match.clock == before.clock)
    #expect(match.id == before.id)
}

@Test func editingToABlankTeamNameChangesNothing() throws {
    var match = try #require(Match.new(details()))
    let before = match
    let applied = match.apply(details("Na Fianna", ""))
    #expect(!applied)
    #expect(match == before)
}

@Test func theCodeCanChangeBeforeThrowIn() throws {
    var match = try #require(Match.new(details()))
    #expect(match.canChangeMatchType)
    let applied = match.apply(details(type: .hurling))
    #expect(applied)
    #expect(match.matchType == .hurling)
}

@Test func theCodeCannotChangeOnceTheMatchHasStarted() throws {
    var match = try #require(Match.new(details()))
    match.start(at: t0)
    #expect(!match.canChangeMatchType)

    let before = match
    var edited = details(type: .hurling)
    edited.venue = "Elsewhere"
    let applied = match.apply(edited)
    #expect(!applied)
    #expect(match == before)

    // Other details can still be edited.
    let sameCode = match.apply(details("Renamed", "Cuala"))
    #expect(sameCode)
    #expect(match.team1.name == "Renamed")
}

@Test func everyCodeHasADisplayName() {
    #expect(MatchType.allCases.map(\.displayName) == ["Football", "Hurling", "Ladies Football", "Camogie"])
}
