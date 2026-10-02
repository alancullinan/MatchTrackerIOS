import Foundation
import MatchCore
import SwiftData

/// A match as SwiftData stores it. `MatchCore.Match` is the model the app works
/// with; this is only how it is saved. Read it with `match()`, write it with
/// `update(from:)`.
///
/// The match's own fields are columns, so the list can sort and filter without
/// decoding anything. The rosters and the event list are encoded as JSON with
/// MatchCore's `Codable`, so each event keeps exactly the shape `MatchEvent.Kind`
/// gives it. See the "Event storage" decision in `PLAN.md`.
///
/// Kept CloudKit-compatible: every property has a default, nothing is unique
/// (`id` is kept unique in code, by `ModelContext.store(_:)`), and properties
/// are only ever added, never renamed or removed.
@Model
final class StoredMatch {
    var id: UUID = UUID()
    var legacyID: String?
    /// A `MatchType` case name.
    var matchType: String = MatchType.football.rawValue
    var competition: String = ""
    var date: Date = Date.distantPast
    var venue: String = ""
    var referee: String = ""
    var liveShareID: String?

    var team1Name: String = ""
    var team2Name: String = ""
    /// `[Player]` as JSON.
    var team1Players: Data = Data()
    var team2Players: Data = Data()
    var team1LastPanelID: UUID?
    var team2LastPanelID: UUID?

    /// `[MatchEvent]` as JSON, in recorded order.
    var events: Data = Data()

    /// A `MatchPeriod` case name.
    var clockPeriod: String = MatchPeriod.notStarted.rawValue
    var clockBankedSeconds: Int = 0
    var clockRunningSince: Date?

    init(_ match: Match) throws {
        id = match.id.uuid
        try update(from: match)
    }

    /// Writes `match` into this record. Fields that haven't changed are left
    /// alone, so saving an unchanged match doesn't mark it for sync.
    func update(from match: Match) throws {
        let team1Players = try StoredCoding.encode(match.team1.players)
        let team2Players = try StoredCoding.encode(match.team2.players)
        let events = try StoredCoding.encode(match.events)

        set(\.legacyID, match.legacyID)
        set(\.matchType, match.matchType.rawValue)
        set(\.competition, match.competition)
        set(\.date, match.date)
        set(\.venue, match.venue)
        set(\.referee, match.referee)
        set(\.liveShareID, match.liveShareID)
        set(\.team1Name, match.team1.name)
        set(\.team2Name, match.team2.name)
        set(\.team1Players, team1Players)
        set(\.team2Players, team2Players)
        set(\.team1LastPanelID, match.team1.lastPanelID?.uuid)
        set(\.team2LastPanelID, match.team2.lastPanelID?.uuid)
        set(\.events, events)
        set(\.clockPeriod, match.clock.period.rawValue)
        set(\.clockBankedSeconds, match.clock.bankedSeconds)
        set(\.clockRunningSince, match.clock.runningSince)
    }

    /// The stored match. Throws rather than guess if anything can't be read,
    /// e.g. a case name written by a newer version of the app.
    func match() throws -> Match {
        Match(
            id: MatchID(id),
            legacyID: legacyID,
            matchType: try StoredCoding.enumCase(MatchType.self, matchType, field: "matchType"),
            competition: competition,
            date: date,
            venue: venue,
            referee: referee,
            team1: Team(
                name: team1Name,
                players: try StoredCoding.decode([Player].self, team1Players, field: "team1Players"),
                lastPanelID: team1LastPanelID.map(PanelID.init)
            ),
            team2: Team(
                name: team2Name,
                players: try StoredCoding.decode([Player].self, team2Players, field: "team2Players"),
                lastPanelID: team2LastPanelID.map(PanelID.init)
            ),
            events: try StoredCoding.decode([MatchEvent].self, events, field: "events"),
            clock: MatchClock(
                period: try StoredCoding.enumCase(MatchPeriod.self, clockPeriod, field: "clockPeriod"),
                bankedSeconds: clockBankedSeconds,
                runningSince: clockRunningSince
            ),
            liveShareID: liveShareID
        )
    }

    private func set<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<StoredMatch, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
