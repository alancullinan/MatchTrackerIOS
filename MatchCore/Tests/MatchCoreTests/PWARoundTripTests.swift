import Foundation
import Testing
@testable import MatchCore

/// The path of the first difference between two parsed JSON values, or nil if
/// they are equal. A key holding `null` and a missing key count as different.
private func firstDifference(_ a: Any, _ b: Any, path: String = "$") -> String? {
    switch (a, b) {
    case let (a as [String: Any], b as [String: Any]):
        if Set(a.keys) != Set(b.keys) {
            return "\(path): keys \(a.keys.sorted()) vs \(b.keys.sorted())"
        }
        for key in a.keys.sorted() {
            if let difference = firstDifference(a[key]!, b[key]!, path: "\(path).\(key)") { return difference }
        }
        return nil
    case let (a as [Any], b as [Any]):
        if a.count != b.count { return "\(path): \(a.count) items vs \(b.count)" }
        for (index, (x, y)) in zip(a, b).enumerated() {
            if let difference = firstDifference(x, y, path: "\(path)[\(index)]") { return difference }
        }
        return nil
    case let (a as NSObject, b as NSObject):
        return a.isEqual(b) ? nil : "\(path): \(a) vs \(b)"
    default:
        return "\(path): \(a) vs \(b)"
    }
}

private func parse(_ data: Data) throws -> Any {
    try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
}

private func reencode<T: Codable>(_ type: T.Type, _ json: String) throws -> [String: Any] {
    let value = try JSONDecoder().decode(type, from: Data(json.utf8))
    return try #require(try parse(JSONEncoder().encode(value)) as? [String: Any])
}

// MARK: - Round trip

@Test func pwaBackupRoundTripsExactly() throws {
    let original = try loadFixture("pwa-backup")
    let backup = try JSONDecoder().decode(PWABackup.self, from: original)
    let written = try JSONEncoder().encode(backup)

    let difference = firstDifference(try parse(original), try parse(written))
    #expect(difference == nil)
}

// MARK: - Writing nulls exactly where the PWA does

@Test func periodEndEventWritesOnlyItsFourFields() throws {
    let object = try reencode(PWAEvent.self, #"{"id":1754851604584,"type":"periodEnd","period":"Full Time","timeElapsed":1900}"#)
    #expect(Set(object.keys) == ["id", "type", "period", "timeElapsed"])
}

@Test func otherEventsWriteEmptyFieldsAsNull() throws {
    let event = PWAEvent(id: .string("1-2"), type: .shot, period: .firstHalf, timeElapsed: 60, teamId: "t", shotOutcome: .point, shotType: .free)
    let object = try #require(try parse(JSONEncoder().encode(event)) as? [String: Any])
    #expect(object.count == 13)
    #expect(object["player1Id"] is NSNull)
    #expect(object["noteText"] is NSNull)
    #expect(object["shotOutcome"] as? String == "point")
}

@Test func matchWritesNullTimestampButOmitsShareFields() throws {
    let object = try reencode(PWAMatch.self, #"{"id":"m","team1":{"id":"a"},"team2":{"id":"b"}}"#)
    #expect(object["periodStartTimestamp"] is NSNull)
    #expect(object["shareId"] == nil)
    #expect(object["isBroadcasting"] == nil)
}

// MARK: - Lenient reading

@Test func unknownKeysAreIgnored() throws {
    let backup = try JSONDecoder().decode(PWABackup.self, from: Data("""
        {"matches":[{"id":"m","team1":{"id":"a","colour":"red"},"team2":{"id":"b"},"weather":"wet",
          "events":[{"id":"e","type":"note","period":"1st Half","timeElapsed":5,"noteText":"x","rating":4}]}],
         "futureField":true}
        """.utf8))
    #expect(backup.matches.first?.events.first?.noteText == "x")
}

@Test func minimalMatchTakesThePWADefaults() throws {
    let match = try JSONDecoder().decode(PWAMatch.self, from: Data(#"{"id":"m","team1":{"id":"a"},"team2":{"id":"b"}}"#.utf8))
    #expect(match.matchType == .football)
    #expect(match.halfLength == 30)
    #expect(match.extraHalfLength == 10)
    #expect(match.currentPeriod == .notStarted)
    #expect(match.isPaused)
    #expect(match.events.isEmpty)
    #expect(match.team1.players.isEmpty)
    #expect(match.periodStartTimestamp == nil)
}

@Test func playerWithoutNameOrPositionDecodes() throws {
    let player = try JSONDecoder().decode(PWAPlayer.self, from: Data(#"{"id":"p","jerseyNumber":3}"#.utf8))
    #expect(player.name == nil)
    #expect(player.position == "")
    #expect(try reencode(PWAPlayer.self, #"{"id":"p","jerseyNumber":3}"#)["name"] == nil)
}

@Test func backupNeedsOnlyMatches() throws {
    let backup = try JSONDecoder().decode(PWABackup.self, from: Data(#"{"matches":[]}"#.utf8))
    #expect(backup.playerPanels.isEmpty)
    #expect(backup.lastSelectedPanels.isEmpty)
}

@Test func malformedLastSelectedPanelsIsDropped() throws {
    let backup = try JSONDecoder().decode(PWABackup.self, from: Data(#"{"matches":[],"lastSelectedPanels":"oops"}"#.utf8))
    #expect(backup.lastSelectedPanels.isEmpty)
}

// MARK: - What must still fail (as in the PWA)

@Test func backupWithoutMatchesIsRejected() {
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(PWABackup.self, from: Data(#"{"playerPanels":[]}"#.utf8))
    }
}

@Test func matchWithoutTeamsIsRejected() {
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(PWAMatch.self, from: Data(#"{"id":"m","team1":{"id":"a"}}"#.utf8))
    }
}
