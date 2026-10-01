import Foundation
import Testing
@testable import MatchCore

func loadFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

private func jsonObject<T: Encodable>(_ value: T) throws -> NSDictionary {
    try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? NSDictionary)
}

// MARK: - The real backup

@Test func decodesThePWABackup() throws {
    let backup = try JSONDecoder().decode(PWABackup.self, from: loadFixture("pwa-backup"))

    #expect(backup.version == "1.0.0")
    #expect(backup.matchCount == 71)
    #expect(backup.panelCount == 6)
    #expect(backup.lastSelectedPanels.count == 49)

    let events = backup.matches.flatMap(\.events)
    #expect(events.count == 2189)
    #expect(events.filter { $0.type == .periodEnd }.allSatisfy {
        if case .number = $0.id { true } else { false }
    })
    #expect(events.contains { $0.shotOutcome == .twoPointer })
    #expect(backup.matches.allSatisfy { $0.team1.players.count == 30 && $0.team2.players.count == 30 })
    #expect(backup.playerPanels.allSatisfy { $0.players.count == 30 })
}

// MARK: - Event ids

@Test func eventIDDecodesStringOrNumber() throws {
    #expect(try decode([PWAEventID].self, #"["1727771234567-123456", 1727771234567]"#)
        == [.string("1727771234567-123456"), .number(1_727_771_234_567)])
}

@Test func eventIDEncodesBackToItsOriginalType() throws {
    let data = try JSONEncoder().encode([PWAEventID.string("1-2"), .number(1_727_771_234_567)])
    #expect(String(decoding: data, as: UTF8.self) == #"["1-2",1727771234567]"#)
}

// MARK: - Players

@Test func playerNameIsKeptAsStored() throws {
    // Converting "No.N" to unnamed is the importer's job, not the PWA type's.
    let player = try decode(PWAPlayer.self, #"{"id":"p","name":"No.7","jerseyNumber":7,"position":""}"#)
    #expect(player.name == "No.7")
}

// MARK: - Events

@Test func decodesPeriodEndEventWithMostFieldsMissing() throws {
    let event = try decode(PWAEvent.self, #"{"id":1754851604584,"type":"periodEnd","period":"Half Time","timeElapsed":1843}"#)
    #expect(event.id == .number(1_754_851_604_584))
    #expect(event.period == .halfTime)
    #expect(event.timeElapsed == 1843)
    #expect(event.teamId == nil)
}

@Test func decodesEventWithNullFields() throws {
    let event = try decode(PWAEvent.self, """
        {"id":"1-2","type":"kickout","period":"1st Half","timeElapsed":95,"teamId":"t","player1Id":null,
         "player2Id":null,"shotOutcome":null,"shotType":null,"foulOutcome":null,"cardType":null,
         "wonKickout":true,"noteText":null}
        """)
    #expect(event.type == .kickout)
    #expect(event.wonKickout == true)
    #expect(event.player1Id == nil)
}

// MARK: - Panels

@Test func decodesLegacyPanelWithoutJerseyNumbers() throws {
    let panel = try decode(PWAPanel.self, #"{"id":"x","name":"U16","players":[{"id":"a","name":"Player 1"}]}"#)
    #expect(panel.players == [PWAPanelPlayer(id: "a", name: "Player 1", jerseyNumber: nil)])
    #expect(panel.createdDate == nil)
}

// MARK: - PWABackup envelope

@Test func backupWritesDerivedCounts() throws {
    let team = PWATeam(id: "t", name: "Team A", players: [])
    let match = PWAMatch(
        id: "m", competition: "", dateTime: "2025-08-10", venue: "", referee: "",
        matchType: .hurling, halfLength: 30, extraHalfLength: 10, team1: team, team2: team
    )
    let backup = PWABackup(exportDate: "2026-10-01T20:39:21.651Z", matches: [match, match], playerPanels: [], lastSelectedPanels: [:])
    let object = try jsonObject(backup)
    #expect(object["matchCount"] as? Int == 2)
    #expect(object["panelCount"] as? Int == 0)
    #expect(object["version"] as? String == "1.0.0")
}
