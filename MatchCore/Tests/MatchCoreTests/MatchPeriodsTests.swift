import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

private func newMatch() -> Match {
    Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: t0)
}

// #expect can't call a mutating method itself, so each step's result is kept first.

private let point = MatchEvent.Kind.shot(side: .team1, player: nil, outcome: .point, type: .fromPlay)

@Test func playingPeriods() {
    #expect(MatchPeriod.allCases.filter(\.isPlaying) == [.firstHalf, .secondHalf, .extraTimeFirstHalf, .extraTimeSecondHalf])
}

@Test func aMatchFinishedAtFullTime() {
    var match = newMatch()
    let started = match.start(at: at(0))
    #expect(started)
    #expect(match.clock == MatchClock(period: .firstHalf, runningSince: at(0)))

    let ended = match.endPeriod(at: at(1900))
    #expect(ended)
    #expect(match.clock == MatchClock(period: .halfTime))

    let started2 = match.start(at: at(2800))
    #expect(started2)
    #expect(match.clock == MatchClock(period: .secondHalf, runningSince: at(2800)))

    let ended2 = match.endPeriod(at: at(4900))
    #expect(ended2)
    #expect(match.clock.period == .fullTime)

    let finished = match.finish()
    #expect(finished)
    #expect(match.clock.period == .matchOver)
    #expect(match.events.map(\.period) == [.firstHalf, .secondHalf])
    #expect(match.events.map(\.time) == [1900, 2100])
    #expect(match.events.allSatisfy { $0.kind == .periodEnd })
}

@Test func extraTimeRunsToMatchOver() {
    var match = newMatch()
    match.start(at: at(0)); match.endPeriod(at: at(10))
    match.start(at: at(20)); match.endPeriod(at: at(30))
    #expect(match.nextPlayingPeriod == .extraTimeFirstHalf)

    let started = match.start(at: at(40))
    #expect(started)
    #expect(match.clock.period == .extraTimeFirstHalf)
    match.endPeriod(at: at(640))
    #expect(match.clock.period == .extraTimeHalfTime)
    match.start(at: at(700))
    #expect(match.clock.period == .extraTimeSecondHalf)
    let ended = match.endPeriod(at: at(1310))
    #expect(ended)

    // Match Over keeps the final time on the clock.
    #expect(match.clock == MatchClock(period: .matchOver, bankedSeconds: 610))
    #expect(match.events.map(\.period) == [.firstHalf, .secondHalf, .extraTimeFirstHalf, .extraTimeSecondHalf])
    let started2 = match.start(at: at(1400))
    #expect(!started2)
    let ended2 = match.endPeriod(at: at(1400))
    #expect(!ended2)
}

@Test func anyMatchCanGoToExtraTime() {
    var match = Match.new(matchType: .hurling, team1Name: "Team A", team2Name: "Team B", date: t0)
    match.start(at: at(0)); match.endPeriod(at: at(10)); match.start(at: at(20)); match.endPeriod(at: at(30))
    let started = match.start(at: at(40))
    #expect(started)
    #expect(match.clock.period == .extraTimeFirstHalf)
}

@Test func finishingIsOnlyForFullTime() {
    var match = newMatch()
    let finished = match.finish()
    #expect(!finished)
    match.start(at: at(0))
    let finished2 = match.finish()
    #expect(!finished2)
    match.endPeriod(at: at(10)); match.start(at: at(20)); match.endPeriod(at: at(30))
    // Full Time offers both: extra time, or finishing.
    #expect(match.nextPlayingPeriod == .extraTimeFirstHalf)
    let finished3 = match.finish()
    #expect(finished3)
    #expect(match.clock.period == .matchOver)
}

@Test func endingAPeriodTwiceRecordsOneEnd() {
    var match = newMatch()
    match.start(at: at(0))
    let ended = match.endPeriod(at: at(1800))
    #expect(ended)
    let ended2 = match.endPeriod(at: at(1801))
    #expect(!ended2)
    #expect(match.events.count == 1)
    #expect(match.clock.period == .halfTime)
}

@Test func endingAPausedPeriodUsesItsBankedTime() {
    var match = newMatch()
    match.start(at: at(0))
    match.pause(at: at(1750))
    match.endPeriod(at: at(1900))
    #expect(match.events.first?.time == 1750)
}

@Test func pauseAndResumeWithinAPeriod() {
    var match = newMatch()
    let paused = match.pause(at: at(0))
    #expect(!paused)
    match.start(at: at(0))
    let paused2 = match.pause(at: at(100))
    #expect(paused2)
    let paused3 = match.pause(at: at(150))
    #expect(!paused3)
    let started = match.start(at: at(200))
    #expect(started)
    let started2 = match.start(at: at(210))
    #expect(!started2)
    #expect(match.clock.period == .firstHalf)
    #expect(match.clock.elapsed(at: at(260)) == 160)
}

@Test func eventsAreRecordedOnlyInPlay() {
    var match = newMatch()
    let recorded = match.record(point, at: at(0))
    #expect(recorded == nil)

    match.start(at: at(0))
    let event = match.record(point, note: "Lovely", at: at(61.5))
    #expect(event?.period == .firstHalf)
    #expect(event?.time == 61)
    #expect(event?.note == "Lovely")
    let recorded2 = match.record(.periodEnd, at: at(70))
    #expect(recorded2 == nil)

    match.endPeriod(at: at(1800))
    #expect(!match.canRecordEvents)
    let recorded3 = match.record(point, at: at(1900))
    #expect(recorded3 == nil)
    #expect(match.events.count == 2)
}

@Test func recordingWhilePausedUsesThePausedTime() {
    var match = newMatch()
    match.start(at: at(0))
    match.pause(at: at(300))
    let recorded = match.record(point, at: at(400))
    #expect(recorded?.time == 300)
}
