import Foundation
import MatchCore
import SwiftData
import Testing
@testable import MatchTracker

@MainActor
struct MatchListTests {
    let context: ModelContext

    init() throws {
        context = ModelContext(try Store.container(inMemory: true))
    }

    @discardableResult
    private func stored(_ team1: String, _ team2: String, competition: String = "", daysAgo: Double = 0) throws -> StoredMatch {
        let date = Date(timeIntervalSince1970: 1_790_000_000 - daysAgo * 86_400)
        return try context.store(Match.new(matchType: .football, team1Name: team1, team2Name: team2,
                                           competition: competition, date: date))
    }

    // MARK: - Search

    @Test func searchMatchesEitherTeamOrTheCompetition() throws {
        let match = try stored("Na Fianna", "Kilmacud Crokes", competition: "Senior Championship")
        #expect(MatchList.matches(match, query: "fianna"))
        #expect(MatchList.matches(match, query: "CROKES"))
        #expect(MatchList.matches(match, query: "senior"))
        #expect(!MatchList.matches(match, query: "Cuala"))
    }

    @Test func searchIgnoresAccents() throws {
        let match = try stored("Seán Mac Cumhaills", "Craobh Chiaráin")
        #expect(MatchList.matches(match, query: "sean"))
        #expect(MatchList.matches(match, query: "chiarain"))
    }

    @Test func everyWordMustMatchSomewhere() throws {
        let match = try stored("Na Fianna", "Kilmacud Crokes", competition: "League")
        #expect(MatchList.matches(match, query: "fianna crokes"))
        #expect(MatchList.matches(match, query: "  crokes   league "))
        #expect(!MatchList.matches(match, query: "fianna cuala"))
    }

    @Test func blankSearchMatchesEverything() throws {
        let match = try stored("A", "B")
        #expect(MatchList.matches(match, query: ""))
        #expect(MatchList.matches(match, query: "   "))
    }

    // MARK: - Order and delete

    @Test func newestMatchesComeFirst() throws {
        try stored("Old", "Match", daysAgo: 30)
        try stored("New", "Match", daysAgo: 0)
        try stored("Middle", "Match", daysAgo: 7)
        let names = try context.fetch(FetchDescriptor(sortBy: MatchList.sortOrder)).map(\.team1Name)
        #expect(names == ["New", "Middle", "Old"])
    }

    @Test func deletingAMatchRemovesIt() throws {
        let keep = try stored("Keep", "Me")
        let remove = try stored("Remove", "Me")
        try context.save()

        try MatchList.delete(remove, from: context)
        let remaining = try context.fetch(FetchDescriptor<StoredMatch>())
        #expect(remaining.map(\.id) == [keep.id])
        #expect(!context.hasChanges)
    }

    // MARK: - Sample data

    @Test func sampleMatchesCoverEveryRowState() throws {
        try SampleMatches.insert(into: context, now: Date(timeIntervalSince1970: 1_790_000_000))
        let all = try context.fetch(FetchDescriptor<StoredMatch>())
        let readable = all.compactMap { try? $0.match() }
        #expect(readable.count == SampleMatches.readableCount)
        #expect(all.count == SampleMatches.readableCount + 1)

        let periods = Set(readable.map(\.clock.period))
        #expect(periods.isSuperset(of: [.notStarted, .secondHalf, .firstHalf, .fullTime, .fullTimeAfterExtraTime]))
        #expect(readable.contains { $0.clock.isRunning })
        #expect(readable.contains { $0.clock.period.isPlaying && !$0.clock.isRunning })
    }
}
