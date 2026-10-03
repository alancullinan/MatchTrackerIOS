import Foundation
import MatchCore
import SwiftData

/// The match list's rules, kept out of the view so they can be tested.
enum MatchList {
    /// Newest first.
    static let sortOrder = [SortDescriptor(\StoredMatch.date, order: .reverse)]

    /// Whether a match fits the search text. Every word must appear in a team
    /// name or the competition, ignoring case and accents ("sean" finds "Seán").
    /// Blank text matches everything. Uses the stored columns, so nothing is decoded.
    static func matches(_ stored: StoredMatch, query: String) -> Bool {
        matches(fields: [stored.team1Name, stored.team2Name, stored.competition], query: query)
    }

    static func matches(fields: [String], query: String) -> Bool {
        query
            .split(whereSeparator: \.isWhitespace)
            .allSatisfy { word in fields.contains { $0.localizedStandardContains(word) } }
    }

    /// Deletes a match and saves straight away, so it can't come back.
    static func delete(_ stored: StoredMatch, from context: ModelContext) throws {
        let id = MatchID(stored.id)
        context.delete(stored)
        try context.save()
        LiveActivities.end(matchID: id)
    }
}
