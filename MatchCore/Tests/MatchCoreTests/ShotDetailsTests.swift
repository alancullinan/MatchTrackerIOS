import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func playing(_ type: MatchType = .football) -> Match {
    var match = Match.new(matchType: type, team1Name: "Team A", team2Name: "Team B", date: t0)
    match.start(at: t0)
    return match
}

private func shot(_ outcome: ShotOutcome, _ side: TeamSide = .team1) -> MatchEvent.Kind {
    .shot(side: side, player: nil, outcome: outcome, type: .fromPlay)
}

// #expect can't call a mutating method itself, so each step's result is kept first.

// MARK: - Choices

@Test func aPointCanBecomeATwoPointerOnlyWhereTheyExist() {
    #expect(ShotOutcome.point.alternatives(in: .football) == [.point, .twoPointer])
    #expect(ShotOutcome.twoPointer.alternatives(in: .ladiesFootball) == [.point, .twoPointer])
    #expect(ShotOutcome.point.alternatives(in: .hurling) == [.point])
    #expect(ShotOutcome.point.alternatives(in: .camogie) == [.point])
}

@Test func aGoalStaysAGoalAndMissesStayMisses() {
    #expect(ShotOutcome.goal.alternatives(in: .football) == [.goal])
    #expect(ShotOutcome.saved.alternatives(in: .hurling) == [.wide, .saved, .droppedShort, .offPost])
}

@Test func footballHasThe45AndHurlingThe65() {
    #expect(ShotType.options(for: .football) == [.fromPlay, .free, .fortyFive, .penalty, .mark, .sideline])
    #expect(ShotType.options(for: .ladiesFootball).contains(.fortyFive))
    #expect(ShotType.options(for: .hurling) == [.fromPlay, .free, .sixtyFive, .penalty, .mark, .sideline])
    #expect(!ShotType.options(for: .camogie).contains(.fortyFive))
}

// MARK: - Updating a shot

@Test func aShotsDetailsCanBeFilledIn() throws {
    var match = playing()
    let recorded = match.record(shot(.point), at: t0.addingTimeInterval(65))
    let event = try #require(recorded)
    let scorer = match.team1.players[10].id

    let updated = match.updateShot(event.id, outcome: .twoPointer, type: .free, player: scorer, note: "  from the right ")
    #expect(updated)
    let after = try #require(match.event(event.id))
    #expect(after.kind == .shot(side: .team1, player: scorer, outcome: .twoPointer, type: .free))
    #expect(after.note == "from the right")
    #expect(after.time == event.time)
    #expect(after.period == event.period)
    #expect(match.score(.team1).points == 2)
}

@Test func aBlankNoteIsCleared() throws {
    var match = playing()
    let recorded = match.record(shot(.goal), note: "old", at: t0)
    let event = try #require(recorded)
    let updated = match.updateShot(event.id, outcome: .goal, type: .penalty, player: nil, note: "   ")
    #expect(updated)
    #expect(match.event(event.id)?.note == nil)
}

@Test func aShotCannotChangeToAnOutcomeOutsideItsGroup() throws {
    var match = playing()
    let recorded = match.record(shot(.point), at: t0)
    let event = try #require(recorded)
    let before = match

    let toGoal = match.updateShot(event.id, outcome: .goal, type: .fromPlay, player: nil, note: nil)
    let toWide = match.updateShot(event.id, outcome: .wide, type: .fromPlay, player: nil, note: nil)
    #expect(!toGoal)
    #expect(!toWide)
    #expect(match == before)
}

@Test func aHurlingPointCannotBecomeATwoPointer() throws {
    var match = playing(.hurling)
    let recorded = match.record(shot(.point), at: t0)
    let event = try #require(recorded)
    let updated = match.updateShot(event.id, outcome: .twoPointer, type: .fromPlay, player: nil, note: nil)
    #expect(!updated)
}

@Test func theScorerMustBeOnThatTeam() throws {
    var match = playing()
    let recorded = match.record(shot(.point, .team1), at: t0)
    let event = try #require(recorded)
    let opponent = match.team2.players[0].id
    let before = match

    let updated = match.updateShot(event.id, outcome: .point, type: .fromPlay, player: opponent, note: nil)
    #expect(!updated)
    #expect(match == before)
}

@Test func onlyShotsCanBeUpdatedThisWay() throws {
    var match = playing()
    let recorded = match.record(.note(side: nil), note: "rain", at: t0)
    let note = try #require(recorded)
    let updated = match.updateShot(note.id, outcome: .point, type: .fromPlay, player: nil, note: nil)
    #expect(!updated)
    let unknown = match.updateShot(EventID(), outcome: .point, type: .fromPlay, player: nil, note: nil)
    #expect(!unknown)
}

// MARK: - Deleting

@Test func anEventCanBeDeleted() throws {
    var match = playing()
    let recorded1 = match.record(shot(.point), at: t0)
    let recorded2 = match.record(shot(.goal), at: t0.addingTimeInterval(10))
    let first = try #require(recorded1)
    let second = try #require(recorded2)

    let deleted = match.deleteEvent(first.id)
    #expect(deleted == first)
    #expect(match.events == [second])
}

@Test func aPeriodEndCannotBeDeleted() throws {
    var match = playing()
    match.endPeriod(at: t0.addingTimeInterval(1900))
    let end = try #require(match.events.last)
    let before = match

    let deleted = match.deleteEvent(end.id)
    #expect(deleted == nil)
    #expect(match == before)
}

@Test func teamsAskForScorersByDefault() {
    let match = playing()
    #expect(match.team1.asksForScorers)
    #expect(match.team2.asksForScorers)
}

@Test func everyShotTypeHasADisplayName() {
    #expect(Set(ShotType.allCases.map(\.displayName)).count == ShotType.allCases.count)
}
