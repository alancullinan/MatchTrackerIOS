import Foundation
import MatchCore
import SwiftData
import Testing
@testable import MatchTracker

/// A whole-second date, so it survives storage exactly.
private let kickOff = Date(timeIntervalSince1970: 1_790_000_000)

/// A match that uses every part of the model: named and unnamed players, a
/// panel id, team colours with and without a second colour, a team not asked
/// for scorers, a running clock,
/// and one event of every kind.
private func sampleMatch() -> Match {
    var match = Match.new(
        matchType: .football,
        team1Name: "Home",
        team2Name: "Away",
        competition: "League",
        date: kickOff,
        venue: "Park",
        referee: "Ref"
    )
    match.legacyID = "1700000000000"
    match.liveShareID = "live-1"
    match.team1.players[10].name = "Named Player"
    match.team2.lastPanelID = PanelID()
    match.team1.colors = TeamColors(.maroon, .white)
    match.team2.colors = TeamColors(.green)
    match.team2.asksForScorers = false
    let scorer = match.team1.players[10].id
    let sub = match.team2.players[20].id
    match.events = [
        MatchEvent(period: .firstHalf, time: 60, note: "from distance",
                   kind: .shot(side: .team1, player: scorer, outcome: .twoPointer, type: .fromPlay)),
        MatchEvent(period: .firstHalf, time: 90,
                   kind: .foul(side: .team2, player: nil, outcome: .free, card: .black)),
        MatchEvent(period: .firstHalf, time: 120, kind: .card(side: .team1, player: scorer, card: .yellow)),
        MatchEvent(period: .firstHalf, time: 150, kind: .kickout(side: .team2, player: nil, won: true)),
        MatchEvent(period: .firstHalf, time: 180, kind: .substitution(side: .team2, off: sub, on: nil)),
        MatchEvent(period: .firstHalf, time: 200, note: "wind", kind: .note(side: nil)),
        MatchEvent(period: .firstHalf, time: 2100, kind: .periodEnd),
    ]
    match.clock = MatchClock(period: .secondHalf, bankedSeconds: 300, runningSince: kickOff.addingTimeInterval(2400))
    return match
}

private func samplePanel() -> PlayerPanel {
    var panel = PlayerPanel.empty(name: "Seniors", createdAt: kickOff)
    panel.legacyID = "panel-1"
    panel.slots[0].name = "Keeper"
    panel.slots[14].name = "Full Forward"
    return panel
}

@MainActor
struct StorageTests {
    let context: ModelContext

    init() throws {
        context = ModelContext(try Store.container(inMemory: true))
    }

    @Test func aStoredMatchReadsBackUnchanged() throws {
        let match = sampleMatch()
        try context.store(match)
        try context.save()

        let stored = try #require(try context.storedMatch(id: match.id))
        #expect(try stored.match() == match)
    }

    @Test func storingAMatchAgainUpdatesTheSameRecord() throws {
        var match = sampleMatch()
        try context.store(match)
        match.venue = "Another Park"
        match.events.removeLast()
        try context.store(match)
        try context.save()

        let all = try context.fetch(FetchDescriptor<StoredMatch>())
        #expect(all.count == 1)
        #expect(try all.first?.match() == match)
    }

    @Test func storingAnUnchangedMatchChangesNothing() throws {
        let match = sampleMatch()
        try context.store(match)
        try context.save()

        try context.store(match)
        #expect(!context.hasChanges)
    }

    @Test func differentMatchesGetTheirOwnRecords() throws {
        try context.store(sampleMatch())
        try context.store(sampleMatch())
        #expect(try context.fetchCount(FetchDescriptor<StoredMatch>()) == 2)
    }

    @Test func anUnknownCaseNameThrowsInsteadOfGuessing() throws {
        let stored = try context.store(sampleMatch())
        stored.clockPeriod = "penaltyShootout"
        #expect(throws: StoredDataError.self) { try stored.match() }
    }

    @Test func anUnknownColourThrowsInsteadOfGuessing() throws {
        let stored = try context.store(sampleMatch())
        stored.team2SecondaryColor = "tartan"
        #expect(throws: StoredDataError.self) { try stored.match() }
    }

    @Test func aMatchWithoutColoursReadsBackWithout() throws {
        var match = sampleMatch()
        match.team1.colors = nil
        let stored = try context.store(match)
        #expect(stored.team1PrimaryColor == nil)
        #expect(stored.team1SecondaryColor == nil)
        #expect(try stored.match().team1.colors == nil)
    }

    @Test func unreadableEventsThrowInsteadOfReadingAsNone() throws {
        let stored = try context.store(sampleMatch())
        stored.events = Data("not json".utf8)
        #expect(throws: StoredDataError.self) { try stored.match() }
    }

    @Test func aStoredPanelReadsBackWithEverySlotInOrder() throws {
        let panel = samplePanel()
        try context.store(panel)
        try context.save()

        let read = try #require(try context.storedPanel(id: panel.id)).panel()
        #expect(read == panel)
        #expect(read.slots.map(\.jerseyNumber) == Array(1...PlayerPanel.startingSize))
    }

    @Test func storingAPanelAgainUpdatesTheSameRecord() throws {
        var panel = samplePanel()
        try context.store(panel)
        panel.name = "Juniors"
        try context.store(panel)

        let all = try context.fetch(FetchDescriptor<StoredPanel>())
        #expect(all.count == 1)
        #expect(try all.first?.panel() == panel)
    }
}
