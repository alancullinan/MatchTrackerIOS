import Foundation
import MatchCore
import SwiftData
import Testing
@testable import MatchTracker

@MainActor
struct MatchFormTests {
    let context: ModelContext
    let date = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        context = ModelContext(try Store.container(inMemory: true))
    }

    private func details(_ team1: String = "Na Fianna", _ team2: String = "Cuala") -> MatchDetails {
        MatchDetails(matchType: .hurling, team1Name: team1, team2Name: team2, competition: "League", date: date)
    }

    private func storedCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<StoredMatch>())
    }

    @Test func aNewMatchStartsNowWithTheCodeGiven() {
        let new = MatchForm.newDetails(matchType: .camogie, now: date)
        #expect(new.matchType == .camogie)
        #expect(new.date == date)
        #expect(!new.isComplete)
    }

    @Test func addingAMatchStoresIt() throws {
        let saved = try #require(try MatchForm.save(details(), editing: nil, in: context))
        let stored = try #require(try context.storedMatch(id: saved.id))
        #expect(try stored.match().details == details())
        #expect(!context.hasChanges)
    }

    @Test func aMatchWithoutBothTeamsIsNotStored() throws {
        let saved = try MatchForm.save(details("Na Fianna", " "), editing: nil, in: context)
        #expect(saved == nil)
        #expect(try storedCount() == 0)
    }

    @Test func editingUpdatesTheSameRecord() throws {
        let original = try #require(Match.new(details()))
        try context.store(original)

        var edited = original.details
        edited.team2Name = "Cuala CLG"
        try MatchForm.save(edited, editing: original.id, in: context)

        #expect(try storedCount() == 1)
        let stored = try #require(try context.storedMatch(id: original.id))
        #expect(stored.team2Name == "Cuala CLG")
    }

    @Test func editingKeepsEventsRecordedSinceTheFormOpened() throws {
        var match = try #require(Match.new(details()))
        try context.store(match)
        let openedWith = match

        // A score is recorded (or synced in) while the form is open.
        match.start(at: date)
        match.record(.shot(side: .team1, player: nil, outcome: .goal, type: .fromPlay), at: date.addingTimeInterval(60))
        try context.store(match)

        var edited = openedWith.details
        edited.venue = "Parnell Park"
        try MatchForm.save(edited, editing: openedWith.id, in: context)

        let saved = try #require(try context.storedMatch(id: match.id)).match()
        #expect(saved.venue == "Parnell Park")
        #expect(saved.events == match.events)
        #expect(saved.clock == match.clock)
    }

    @Test func editingAMatchThatIsGoneThrows() throws {
        let match = try #require(Match.new(details()))
        #expect(throws: MatchForm.SaveError.self) {
            try MatchForm.save(match.details, editing: match.id, in: context)
        }
    }
}
