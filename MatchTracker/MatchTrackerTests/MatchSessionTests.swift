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

    // MARK: - Scorer sheet

    @Test func aScoreOpensTheScorerSheet() {
        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team1, .point), at: at(60))
        #expect(session.detailsEvent == session.match.events.last?.id)
    }

    @Test func aTeamThatIsNotAskedForScorersSkipsTheSheet() throws {
        session.setAsksForScorers(false, for: .team2)
        #expect(try stored().team2.asksForScorers == false)

        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team2, .goal), at: at(60))
        #expect(session.detailsEvent == nil)
        #expect(session.match.score(.team2).goals == 1)
    }

    @Test func aMissIsAWideAndAlwaysOpensTheSheet() throws {
        session.setAsksForScorers(false, for: .team1)
        session.perform(.nextStep, at: at(0))
        session.perform(.miss(.team1), at: at(60))

        let miss = try #require(session.match.events.last)
        #expect(miss.kind == .shot(side: .team1, player: nil, outcome: .wide, type: .fromPlay))
        #expect(session.detailsEvent == miss.id)
    }

    @Test func doneSavesTheShotsDetails() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team1, .point), at: at(60))
        let id = try #require(session.detailsEvent)
        let scorer = session.match.team1.players[13].id

        let saved = session.updateShot(id, outcome: .twoPointer, type: .free, player: scorer, note: nil)
        #expect(saved)
        #expect(try stored().event(id)?.kind == .shot(side: .team1, player: scorer, outcome: .twoPointer, type: .free))
    }

    @Test func undoOnTheSheetRemovesTheScore() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.score(.team1, .goal), at: at(60))
        let id = try #require(session.detailsEvent)

        let deleted = session.deleteEvent(id)
        #expect(deleted)
        #expect(session.match.events.isEmpty)
        #expect(session.undoable == nil)
        #expect(try stored().events.isEmpty)
    }

    // MARK: - Fouls, kickouts, substitutions and notes

    @Test func aFoulIsAFreeAndOpensItsSheet() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.foul(.team2), at: at(300))

        let foul = try #require(session.match.events.last)
        #expect(foul.kind == .foul(side: .team2, player: nil, outcome: .free, card: nil))
        #expect(foul.time == 300)
        #expect(session.detailsEvent == foul.id)
        #expect(session.undoable == .event(foul.id))
    }

    @Test func aFoulsDetailsAreSaved() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.foul(.team1), at: at(300))
        let id = try #require(session.detailsEvent)
        let fouler = session.match.team1.players[3].id

        let saved = session.updateFoul(id, outcome: .penalty, card: .black, player: fouler, note: nil)
        #expect(saved)
        #expect(try stored().event(id)?.kind == .foul(side: .team1, player: fouler, outcome: .penalty, card: .black))
    }

    @Test func aKickoutIsWonUntilChanged() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.kickout(.team1), at: at(120))
        let id = try #require(session.detailsEvent)
        #expect(session.match.event(id)?.kind == .kickout(side: .team1, player: nil, won: true))

        let saved = session.updateKickout(id, won: false, player: nil, note: nil)
        #expect(saved)
        #expect(try stored().event(id)?.kind == .kickout(side: .team1, player: nil, won: false))
    }

    @Test func aSubstitutionsPlayersAreSaved() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.substitution(.team2), at: at(1500))
        let id = try #require(session.detailsEvent)
        let off = session.match.team2.players[9].id
        let on = session.match.team2.players[19].id

        let saved = session.updateSubstitution(id, off: off, on: on, note: nil)
        #expect(saved)
        #expect(try stored().event(id)?.kind == .substitution(side: .team2, off: off, on: on))
    }

    @Test func aNoteKeepsTheTimeItWasStarted() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.note(nil), at: at(600))
        let id = try #require(session.detailsEvent)

        let saved = session.saveNote(id, text: "Wind changing")
        #expect(saved)
        let note = try #require(try stored().event(id))
        #expect(note.note == "Wind changing")
        #expect(note.time == 600)
        #expect(note.kind == .note(side: nil))
    }

    @Test func aBlankNoteIsDeleted() throws {
        session.perform(.nextStep, at: at(0))
        session.perform(.note(.team1), at: at(600))
        let id = try #require(session.detailsEvent)

        session.saveNote(id, text: "  ")
        #expect(session.match.events.isEmpty)
        #expect(try stored().events.isEmpty)
    }

    @Test func nothingIsRecordedWhileTheBallIsNotInPlay() {
        let recorded = [
            session.perform(.foul(.team1), at: at(0)),
            session.perform(.kickout(.team1), at: at(0)),
            session.perform(.substitution(.team1), at: at(0)),
            session.perform(.note(nil), at: at(0)),
        ]
        #expect(!recorded.contains(true))
        #expect(session.match.events.isEmpty)
        #expect(session.detailsEvent == nil)
    }
}
