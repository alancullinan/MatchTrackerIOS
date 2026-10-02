import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

private func newMatch() -> Match {
    Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: t0)
}

private let point = MatchEvent.Kind.shot(side: .team1, player: nil, outcome: .point, type: .fromPlay)

// #expect can't call a mutating method itself, so each step's result is kept first.

// MARK: - Next step

@Test func theNextStepWalksThroughTheWholeMatch() {
    var match = newMatch()
    var titles: [String] = []
    var time: Double = 0
    while let step = match.nextStep {
        titles.append(step.title)
        time += 60
        let taken = match.takeNextStep(at: at(time))
        #expect(taken)
    }
    #expect(titles == [
        "Start 1st Half", "End 1st Half", "Start 2nd Half", "End 2nd Half",
        "Start Extra Time", "End ET 1st Half", "Start ET 2nd Half", "End Extra Time",
    ])
    #expect(match.clock.period == .fullTimeAfterExtraTime)
    let after = match.takeNextStep(at: at(time + 60))
    #expect(!after)
}

@Test func whilePausedTheNextStepIsStillToEndThePeriod() {
    var match = newMatch()
    match.start(at: at(0))
    match.pause(at: at(100))
    #expect(match.nextStep == .end(.firstHalf))
}

// MARK: - Undoing events

@Test func undoRemovesTheLastRecordedEvent() throws {
    var match = newMatch()
    match.start(at: at(0))
    let recorded1 = match.record(point, at: at(10))
    let recorded2 = match.record(point, at: at(20))
    let first = try #require(recorded1)
    let second = try #require(recorded2)

    let undone = match.undoLastEvent()
    #expect(undone == second)
    #expect(match.events == [first])
    #expect(match.clock.isRunning)
}

@Test func undoWithNoEventsChangesNothing() {
    var match = newMatch()
    let before = match
    let undone = match.undoLastEvent()
    #expect(undone == nil)
    #expect(match == before)
}

@Test func undoingAPeriodEndGoesBackIntoThePeriodPaused() throws {
    var match = newMatch()
    match.start(at: at(0))
    match.record(point, at: at(60))
    match.endPeriod(at: at(1900))

    let undoneEvent = match.undoLastEvent()
    let undone = try #require(undoneEvent)
    #expect(undone.kind == .periodEnd)
    #expect(match.clock == MatchClock(period: .firstHalf, bankedSeconds: 1900))
    #expect(match.events.count == 1)

    // Play resumes from where the period ended.
    match.start(at: at(2000))
    #expect(match.clock.elapsed(at: at(2010)) == 1910)
}

@Test func undoingTheEndOfExtraTimeGoesBackIntoIt() {
    var match = newMatch()
    var time: Double = 0
    while match.nextStep != nil { time += 60; match.takeNextStep(at: at(time)) }
    #expect(match.clock.period == .fullTimeAfterExtraTime)

    let undone = match.undoLastEvent()
    #expect(undone?.kind == .periodEnd)
    #expect(match.clock == MatchClock(period: .extraTimeSecondHalf, bankedSeconds: 60))
}

@Test func aPeriodEndCannotBeUndoneOnceTheNextPeriodHasStarted() {
    var match = newMatch()
    match.start(at: at(0))
    match.endPeriod(at: at(1900))
    match.start(at: at(2800))
    let before = match

    let undone = match.undoLastEvent()
    #expect(undone == nil)
    #expect(match == before)
}

// MARK: - Undoing a period start

@Test func undoingAStartGoesBackToTheBreak() {
    var match = newMatch()
    match.start(at: at(0))
    let undone = match.undoPeriodStart()
    #expect(undone)
    #expect(match.clock == MatchClock(period: .notStarted))

    match.start(at: at(0))
    match.endPeriod(at: at(1900))
    match.start(at: at(2800))
    let undone2 = match.undoPeriodStart()
    #expect(undone2)
    #expect(match.clock == MatchClock(period: .halfTime))
    #expect(match.nextStep == .start(.secondHalf))
}

@Test func undoingExtraTimeGoesBackToFullTime() {
    var match = newMatch()
    var time: Double = 0
    while match.clock.period != .fullTime { time += 60; match.takeNextStep(at: at(time)) }
    match.start(at: at(time + 60))
    let undone = match.undoPeriodStart()
    #expect(undone)
    #expect(match.clock == MatchClock(period: .fullTime))
}

@Test func aStartCannotBeUndoneOnceSomethingIsRecorded() {
    var match = newMatch()
    match.start(at: at(0))
    match.record(point, at: at(10))
    let before = match
    let undone = match.undoPeriodStart()
    #expect(!undone)
    #expect(match == before)
}

@Test func aStartCannotBeUndoneDuringABreak() {
    var match = newMatch()
    let undone = match.undoPeriodStart()
    #expect(!undone)
    #expect(match.clock == MatchClock())
}

// MARK: - Display

@Test func theLastPeriodEndIsTheLatestInMatchOrder() {
    var match = newMatch()
    #expect(match.lastPeriodEnd == nil)
    match.start(at: at(0))
    match.endPeriod(at: at(1860))
    match.start(at: at(2400))
    match.endPeriod(at: at(4400))
    #expect(match.lastPeriodEnd?.period == .secondHalf)
    #expect(match.lastPeriodEnd?.time == 2000)
}

@Test func clockTextIsMinutesAndSeconds() {
    #expect(MatchClock.text(seconds: 0) == "00:00")
    #expect(MatchClock.text(seconds: 65) == "01:05")
    #expect(MatchClock.text(seconds: 23 * 60 + 14) == "23:14")
    #expect(MatchClock.text(seconds: 63 * 60 + 40) == "63:40")
    #expect(MatchClock.text(seconds: -5) == "00:00")
}

@Test func theFirstMinuteOfAPeriodIsMinuteOne() {
    #expect(MatchEvent(period: .firstHalf, time: 0, kind: point).minute == 1)
    #expect(MatchEvent(period: .firstHalf, time: 59, kind: point).minute == 1)
    #expect(MatchEvent(period: .firstHalf, time: 22 * 60 + 5, kind: point).minute == 23)
}
