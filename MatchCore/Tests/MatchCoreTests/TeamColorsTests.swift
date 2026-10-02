import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func details(team1: TeamColors? = nil, team2: TeamColors? = nil) -> MatchDetails {
    MatchDetails(team1Name: "Kilkenny", team2Name: "Tipperary", team1Colors: team1, team2Colors: team2, date: t0)
}

@Test func kitColorsAreStoredByCaseName() throws {
    // Case names are a stored format: this list may grow but never change.
    #expect(KitColor.allCases.map(\.rawValue) == [
        "white", "black", "red", "maroon", "green", "gold",
        "orange", "primrose", "blue", "skyBlue", "navy", "purple",
    ])
}

@Test func aSecondColourTheSameAsTheMainOneIsDropped() {
    #expect(TeamColors(.red, .red) == TeamColors(.red))
    #expect(TeamColors(.red, .red).secondary == nil)
    #expect(TeamColors(.black, .gold).secondary == .gold)
}

@Test func teamsHaveNoColoursUntilChosen() throws {
    let match = try #require(Match.new(details()))
    #expect(match.team1.colors == nil)
    #expect(match.team2.colors == nil)
}

@Test func aNewMatchKeepsTheColoursChosen() throws {
    let match = try #require(Match.new(details(team1: TeamColors(.black, .gold), team2: TeamColors(.blue, .gold))))
    #expect(match.team1.colors == TeamColors(.black, .gold))
    #expect(match.team2.colors == TeamColors(.blue, .gold))
    #expect(match.details.team1Colors == TeamColors(.black, .gold))
}

@Test func coloursCanChangeAfterThrowIn() throws {
    var match = try #require(Match.new(details()))
    match.start(at: t0)

    var edited = match.details
    edited.team2Colors = TeamColors(.blue, .gold)
    let applied = match.apply(edited)

    #expect(applied)
    #expect(match.team2.colors == TeamColors(.blue, .gold))
}

@Test func coloursCanBeCleared() throws {
    var match = try #require(Match.new(details(team1: TeamColors(.white))))
    var edited = match.details
    edited.team1Colors = nil
    let applied = match.apply(edited)
    #expect(applied)
    #expect(match.team1.colors == nil)
}

@Test func everyKitColorHasADisplayName() {
    #expect(Set(KitColor.allCases.map(\.displayName)).count == KitColor.allCases.count)
}
