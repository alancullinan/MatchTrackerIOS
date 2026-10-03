import Foundation
import MatchCore
import Testing
@testable import MatchTracker

struct EventListTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func eventsAreNewestFirstAcrossPeriods() throws {
        var match = Match.new(matchType: .football, team1Name: "A", team2Name: "B", date: t0)
        match.start(at: t0)
        let firstRecorded = match.record(.kickout(side: .team1, player: nil, won: true), at: at(60))
        let first = try #require(firstRecorded)
        let secondRecorded = match.record(.note(side: nil), note: "Wind", at: at(120))
        let second = try #require(secondRecorded)
        match.endPeriod(at: at(1800))
        let end = try #require(match.events.last)
        match.start(at: at(2400))
        let thirdRecorded = match.record(.substitution(side: .team2, off: nil, on: nil), at: at(2500))
        let third = try #require(thirdRecorded)

        #expect(EventList(match).events.map(\.id) == [third.id, end.id, second.id, first.id])
    }

    @Test func theEventOnTheCardIsLeftOut() throws {
        var match = Match.new(matchType: .football, team1Name: "A", team2Name: "B", date: t0)
        match.start(at: t0)
        let firstRecorded = match.record(.kickout(side: .team1, player: nil, won: true), at: at(60))
        let first = try #require(firstRecorded)
        match.endPeriod(at: at(1800))
        match.start(at: at(2400))
        let lastRecorded = match.record(.note(side: nil), note: "Wind", at: at(2500))
        let last = try #require(lastRecorded)

        let ids = EventList(match, excluding: last.id).events.map(\.id)
        #expect(ids.contains(first.id))
        #expect(!ids.contains(last.id))
    }

    @Test func aMatchWithNoEventsListsNothing() {
        let match = Match.new(matchType: .hurling, team1Name: "A", team2Name: "B", date: t0)
        #expect(EventList(match).events.isEmpty)
    }
}
