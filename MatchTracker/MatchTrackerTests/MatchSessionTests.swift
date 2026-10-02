import Foundation
import MatchCore
import SwiftData
import Testing
@testable import MatchTracker

@MainActor
struct MatchSessionTests {
    let context: ModelContext
    let session: MatchSession
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        context = ModelContext(try Store.container(inMemory: true))
        let match = Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "Cuala", date: t0)
        try context.store(match)
        try context.save()
        session = MatchSession(match: match, context: context)
    }

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func stored() throws -> Match {
        try #require(try context.storedMatch(id: session.match.id)).match()
    }

    @Test func everyChangeIsSavedStraightAway() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team1, .goal), at: at(60))
        #expect(try stored() == session.match)
        #expect(try stored().score(.team1).goals == 1)
        #expect(!context.hasChanges)
    }

    @Test func aFlagDoesNothingWhileTheBallIsNotInPlay() throws {
        let scored = session.perform(.score(.team1, .point), at: at(0))
        #expect(!scored)
        #expect(session.match.events.isEmpty)
        #expect(session.changeCount == 0)
    }

    @Test func aScoreCanBeUndone() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team2, .point), at: at(60))
        #expect(session.undoable != nil)

        let undone = session.undo()
        #expect(undone)
        #expect(session.match.events.isEmpty)
        #expect(try stored().events.isEmpty)
        #expect(session.undoable == nil)
    }

    @Test func endingAPeriodCanBeUndone() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.nextStep, at: at(1900))
        #expect(session.match.clock.period == .halfTime)

        session.undo()
        #expect(session.match.clock == MatchClock(period: .firstHalf, bankedSeconds: 1900))
        #expect(try stored().clock == session.match.clock)
    }

    @Test func startingAPeriodCanBeUndone() throws {
        session.perform(.nextStep, at: at(0))
        #expect(session.undoable == .periodStart(.firstHalf))

        session.undo()
        #expect(session.match.clock == MatchClock(period: .notStarted))
        #expect(try stored().clock.period == .notStarted)
    }

    @Test func pausingDoesNotReplaceWhatUndoWouldReverse() {
        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team1, .point), at: at(60))
        let undoable = session.undoable

        session.perform(.pause, at: at(70))
        session.perform(.resume, at: at(80))
        #expect(session.undoable == undoable)
    }

    @Test func undoDoesNothingOnceItHasBeenCleared() {
        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team1, .point), at: at(60))
        session.clearUndo()

        let undone = session.undo()
        #expect(!undone)
        #expect(session.match.events.count == 1)
    }

    @Test func resumeOnlyAppliesToAPausedPeriod() {
        let resumedBeforeStart = session.perform(.resume, at: at(0))
        #expect(!resumedBeforeStart)
        #expect(session.match.clock.period == .notStarted)

        session.perform(.nextStep, at: at(0))
        session.perform(.pause, at: at(100))
        let resumed = session.perform(.resume, at: at(200))
        #expect(resumed)
        #expect(session.match.clock.elapsed(at: at(210)) == 110)
    }

    @Test func reloadPicksUpAnEditMadeElsewhere() throws {
        var edited = session.match
        edited.venue = "Parnell Park"
        try context.store(edited)
        try context.save()

        session.reload()
        #expect(session.match.venue == "Parnell Park")
    }
}
