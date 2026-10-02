import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

private func playing() -> Match {
    var match = Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: t0)
    match.start(at: t0)
    return match
}

private func point(_ side: TeamSide = .team1) -> MatchEvent.Kind {
    .shot(side: side, player: nil, outcome: .point, type: .fromPlay)
}

// #expect can't call a mutating method itself, so each step's result is kept first.

// MARK: - The clock

@Test func aRunningClockCanBeMovedOnAndKeepsRunning() {
    var match = playing()
    let adjusted = match.adjustClock(by: 60, at: at(100))
    #expect(adjusted)
    #expect(match.clock.isRunning)
    #expect(match.clock.elapsed(at: at(100)) == 160)
    #expect(match.clock.elapsed(at: at(110)) == 170)
}

@Test func aPausedClockCanBeMovedBackAndStaysPaused() {
    var match = playing()
    match.pause(at: at(300))
    let adjusted = match.adjustClock(by: -45, at: at(400))
    #expect(adjusted)
    #expect(match.clock == MatchClock(period: .firstHalf, bankedSeconds: 255))
}

@Test func theClockNeverGoesBelowZero() {
    var match = playing()
    match.adjustClock(by: -600, at: at(30))
    #expect(match.clock.elapsed(at: at(30)) == 0)
}

@Test func theClockCantBeAdjustedDuringABreak() {
    var match = playing()
    match.endPeriod(at: at(1800))
    let before = match
    let adjusted = match.adjustClock(by: 60, at: at(1900))
    #expect(!adjusted)
    #expect(match == before)
}

// MARK: - Event times

@Test func anEventCanBeMovedToAnotherTime() throws {
    var match = playing()
    let recorded = match.record(point(), at: at(600))
    let event = try #require(recorded)

    let moved = match.updateTime(event.id, period: .firstHalf, time: 540)
    #expect(moved)
    #expect(match.event(event.id)?.time == 540)
    #expect(match.event(event.id)?.kind == event.kind)
}

@Test func anEventCanBeMovedToAnEarlierPeriodButNotPastItsEnd() throws {
    var match = playing()
    match.endPeriod(at: at(1900))
    match.start(at: at(2500))
    let recorded = match.record(point(), at: at(2560))
    let event = try #require(recorded)

    #expect(match.timeLimits(for: event.id, in: .firstHalf) == 0...1900)
    let tooLate = match.updateTime(event.id, period: .firstHalf, time: 1950)
    #expect(!tooLate)
    let moved = match.updateTime(event.id, period: .firstHalf, time: 1880)
    #expect(moved)
    #expect(match.eventsInOrder.map(\.id) == [event.id, match.events[0].id])
    #expect(match.score(.team1, through: match.events[0].id)?.total == 1)
}

@Test func anEventCantBeMovedToAPeriodNotYetPlayed() throws {
    var match = playing()
    let recorded = match.record(point(), at: at(60))
    let event = try #require(recorded)

    #expect(match.playedPeriods == [.firstHalf])
    let moved = match.updateTime(event.id, period: .secondHalf, time: 60)
    #expect(!moved)
}

@Test func aPeriodEndCanBeMovedButNotBeforeTheLastEventInIt() throws {
    var match = playing()
    match.record(point(), at: at(1700))
    match.endPeriod(at: at(1950))
    let end = try #require(match.events.last)

    #expect(match.timeLimits(for: end.id, in: .firstHalf) == 1700...Match.maxEventTime)
    #expect(match.timeLimits(for: end.id, in: .secondHalf) == nil)
    let tooEarly = match.updateTime(end.id, period: .firstHalf, time: 1650)
    #expect(!tooEarly)
    let moved = match.updateTime(end.id, period: .firstHalf, time: 1800)
    #expect(moved)
    #expect(match.lastPeriodEnd?.time == 1800)
}

@Test func aNegativeTimeIsRefused() throws {
    var match = playing()
    let recorded = match.record(point(), at: at(60))
    let event = try #require(recorded)

    let moved = match.updateTime(event.id, period: .firstHalf, time: -1)
    #expect(!moved)
}
