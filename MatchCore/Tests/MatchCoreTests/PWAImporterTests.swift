import Foundation
import Testing
@testable import MatchCore

private let dublin = TimeZone(identifier: "Europe/Dublin")!

private func fixture() throws -> PWABackup {
    try JSONDecoder().decode(PWABackup.self, from: loadFixture("pwa-backup"))
}

private func backup(_ json: String) throws -> PWABackup {
    try JSONDecoder().decode(PWABackup.self, from: Data(json.utf8))
}

/// A one-match backup. Team ids are "a" and "b"; players are "a1"/"a2" and "b1".
private func oneMatch(events: String = "[]", extra: String = "", panels: String = "[]", lastSelected: String = "{}") throws -> PWABackup {
    try backup("""
        {"matches":[{"id":"1754435709770-961121","dateTime":"2025-08-10","matchType":"football","extraHalfLength":10\(extra),
          "team1":{"id":"a","name":"Team A","players":[{"id":"a1","name":"No.1","jerseyNumber":1},{"id":"a2","name":" Seán ","jerseyNumber":2}]},
          "team2":{"id":"b","name":"Team B","players":[{"id":"b1","name":"No.1","jerseyNumber":1}]},
          "events":\(events)}],
         "playerPanels":\(panels),"lastSelectedPanels":\(lastSelected)}
        """)
}

private func points(_ outcome: ShotOutcome) -> Int {
    switch outcome {
    case .goal: 3
    case .point: 1
    case .twoPointer: 2
    default: 0
    }
}

// MARK: - The real backup

@Test func everyMatchAndPanelInTheFixtureConverts() throws {
    let source = try fixture()
    let result = try PWAImporter.convert(source, timeZone: dublin)

    #expect(result.matches.count == 71)
    #expect(result.panels.count == 6)
    #expect(result.skippedMatchIDs.isEmpty)
    #expect(result.warnings.isEmpty)
    #expect(result.matches.map(\.legacyID) == source.matches.map(\.id))
    #expect(result.panels.allSatisfy { $0.slots.map(\.jerseyNumber) == Array(1...30) })
}

@Test func everyMatchKeepsItsScoreAndEvents() throws {
    let source = try fixture()
    let result = try PWAImporter.convert(source, timeZone: dublin)

    for (pwa, match) in zip(source.matches, result.matches) {
        #expect(match.events.count == pwa.events.count, "\(pwa.id)")
        for side in TeamSide.allCases {
            let teamID = side == .team1 ? pwa.team1.id : pwa.team2.id
            let before = pwa.events.filter { $0.teamId == teamID }.compactMap(\.shotOutcome).map(points).reduce(0, +)
            let after = match.events.compactMap { event -> Int? in
                guard case .shot(let s, _, let outcome, _) = event.kind, s == side else { return nil }
                return points(outcome)
            }.reduce(0, +)
            #expect(before == after, "\(pwa.id) \(side)")
        }
    }
}

@Test func fixturePlayersAndPanelChoicesCarryOver() throws {
    let source = try fixture()
    let result = try PWAImporter.convert(source, timeZone: dublin)

    let pwaNamed = source.matches.flatMap { [$0.team1, $0.team2] }.flatMap(\.players).filter { player in
        let name = player.name ?? ""
        // "No.N" is the unnamed placeholder; an empty name is unnamed too.
        return name != "No.\(player.jerseyNumber)" && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }.count
    let named = result.matches.flatMap { [$0.team1, $0.team2] }.flatMap(\.players).filter { $0.name != nil }.count
    #expect(named == pwaNamed)
    // 47 of the 49 remembered panel choices belong to matches in the backup.
    #expect(result.matches.flatMap { [$0.team1.lastPanelID, $0.team2.lastPanelID] }.compactMap { $0 }.count == 47)
}

@Test func runningTheImportAgainSkipsEverything() throws {
    let source = try fixture()
    let first = try PWAImporter.convert(source, timeZone: dublin)
    let again = try PWAImporter.convert(
        source,
        existingMatchIDs: Set(first.matches.compactMap(\.legacyID)),
        existingPanels: Dictionary(uniqueKeysWithValues: first.panels.map { ($0.legacyID!, $0.id) }),
        timeZone: dublin
    )
    #expect(again.matches.isEmpty)
    #expect(again.panels.isEmpty)
    #expect(again.skippedMatchIDs.count == 71)
    #expect(again.skippedPanelIDs.count == 6)
}

// MARK: - Matches

@Test func unnamedPlayersBecomeNilAndNamesAreTrimmed() throws {
    let match = try #require(try PWAImporter.convert(oneMatch()).matches.first)
    #expect(match.team1.players.map(\.name) == [nil, "Seán"])
    #expect(match.team2.players.map(\.name) == [nil])
}

@Test func eventsMapTeamsAndPlayers() throws {
    let match = try #require(try PWAImporter.convert(oneMatch(events: """
        [{"id":"e1","type":"shot","period":"1st Half","timeElapsed":61,"teamId":"b","player1Id":"b1","shotOutcome":"twoPointer","shotType":"free","noteText":"Great score"},
         {"id":"e2","type":"substitution","period":"2nd Half","timeElapsed":5,"teamId":"a","player1Id":"a1","player2Id":"a2"},
         {"id":"e3","type":"foulConceded","period":"2nd Half","timeElapsed":9,"teamId":"a","player1Id":null,"foulOutcome":"free","cardType":null},
         {"id":"e4","type":"note","period":"2nd Half","timeElapsed":9,"teamId":null,"noteText":"Rain"},
         {"id":"e5","type":"kickout","period":"2nd Half","timeElapsed":10,"teamId":"b","wonKickout":false},
         {"id":"e6","type":"card","period":"2nd Half","timeElapsed":11,"teamId":"a","player1Id":"a2","cardType":"yellow"}]
        """)).matches.first)
    let b1 = match.team2.players[0].id
    let (a1, a2) = (match.team1.players[0].id, match.team1.players[1].id)

    #expect(match.events.map(\.kind) == [
        .shot(side: .team2, player: b1, outcome: .twoPointer, type: .free),
        .substitution(side: .team1, off: a1, on: a2),
        .foul(side: .team1, player: nil, outcome: .free, card: nil),
        .note(side: nil),
        .kickout(side: .team2, player: nil, won: false),
        .card(side: .team1, player: a2, card: .yellow),
    ])
    #expect(match.events[0].period == .firstHalf)
    #expect(match.events[0].time == 61)
    #expect(match.events[0].note == "Great score")
    #expect(match.events[3].note == "Rain")
}

@Test func periodEndsRecordThePeriodThatEnded() throws {
    let match = try #require(try PWAImporter.convert(oneMatch(events: """
        [{"id":1,"type":"periodEnd","period":"Half Time","timeElapsed":1900},
         {"id":2,"type":"periodEnd","period":"Full Time","timeElapsed":2000},
         {"id":"e","type":"shot","period":"Extra Time 1st Half","timeElapsed":30,"teamId":"a","shotOutcome":"point","shotType":"fromPlay"},
         {"id":3,"type":"periodEnd","period":"Extra Time Half Time","timeElapsed":600},
         {"id":4,"type":"periodEnd","period":"Match Over","timeElapsed":650}]
        """)).matches.first)
    let ends = match.events.filter { $0.kind == .periodEnd }
    #expect(ends.map(\.period) == [.firstHalf, .secondHalf, .extraTimeFirstHalf, .extraTimeSecondHalf])
    #expect(ends.map(\.time) == [1900, 2000, 600, 650])
}

@Test func matchOverAfterFullTimeIsDroppedWithAWarning() throws {
    let result = try PWAImporter.convert(oneMatch(events: """
        [{"id":1,"type":"periodEnd","period":"Full Time","timeElapsed":2000},
         {"id":2,"type":"periodEnd","period":"Match Over","timeElapsed":0}]
        """))
    #expect(result.matches[0].events.map(\.period) == [.secondHalf])
    #expect(result.warnings.count == 1)
}

@Test func aPeriodEndIntoAPlayingPeriodIsAnError() throws {
    #expect(throws: PWAImportError.unexpectedPeriodEnd(matchID: "1754435709770-961121", eventID: "7", period: .secondHalf)) {
        try PWAImporter.convert(oneMatch(events: #"[{"id":7,"type":"periodEnd","period":"2nd Half","timeElapsed":0}]"#))
    }
}

@Test func badReferencesAndMissingFieldsAreErrors() throws {
    #expect(throws: PWAImportError.unknownTeam(matchID: "1754435709770-961121", eventID: "x")) {
        try PWAImporter.convert(oneMatch(events: #"[{"id":"x","type":"shot","period":"1st Half","timeElapsed":0,"teamId":"zz","shotOutcome":"goal","shotType":"free"}]"#))
    }
    #expect(throws: PWAImportError.unknownPlayer(matchID: "1754435709770-961121", eventID: "x", playerID: "zz")) {
        try PWAImporter.convert(oneMatch(events: #"[{"id":"x","type":"shot","period":"1st Half","timeElapsed":0,"teamId":"a","player1Id":"zz","shotOutcome":"goal","shotType":"free"}]"#))
    }
    #expect(throws: PWAImportError.missingField(matchID: "1754435709770-961121", eventID: "x", field: "shotType")) {
        try PWAImporter.convert(oneMatch(events: #"[{"id":"x","type":"shot","period":"1st Half","timeElapsed":0,"teamId":"a","shotOutcome":"goal"}]"#))
    }
}

@Test func aPausedClockKeepsItsTime() throws {
    let match = try #require(try PWAImporter.convert(oneMatch(extra: #","currentPeriod":"2nd Half","elapsedTime":754,"isPaused":true,"periodStartTimestamp":1754850000000"#)).matches.first)
    #expect(match.clock == MatchClock(period: .secondHalf, bankedSeconds: 754))
}

@Test func aRunningClockKeepsCounting() throws {
    let match = try #require(try PWAImporter.convert(oneMatch(extra: #","currentPeriod":"1st Half","elapsedTime":12,"isPaused":false,"periodStartTimestamp":1754850000000"#)).matches.first)
    let start = Date(timeIntervalSince1970: 1_754_850_000)
    #expect(match.clock.runningSince == start)
    #expect(match.clock.elapsed(at: start.addingTimeInterval(300)) == 300)
}

@Test func theDateIsMiddayOnTheEnteredDay() throws {
    let match = try #require(try PWAImporter.convert(oneMatch(), timeZone: dublin).matches.first)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = dublin
    let parts = calendar.dateComponents([.year, .month, .day, .hour], from: match.date)
    #expect([parts.year, parts.month, parts.day, parts.hour] == [2025, 8, 10, 12])
}

@Test func aMissingDateFallsBackToWhenTheMatchWasCreated() throws {
    let source = try backup(#"{"matches":[{"id":"1754435709770-961121","team1":{"id":"a"},"team2":{"id":"b"}}]}"#)
    #expect(try PWAImporter.convert(source).matches[0].date == Date(timeIntervalSince1970: 1_754_435_709.770))
}

@Test func otherMatchFieldsCarryOver() throws {
    let match = try #require(try PWAImporter.convert(oneMatch(extra: #","competition":"Junior C","venue":"Venue 1","referee":"Referee 1","halfLength":35,"shareId":"abc","isBroadcasting":true"#)).matches.first)
    #expect(match.legacyID == "1754435709770-961121")
    #expect(match.matchType == .football)
    #expect([match.competition, match.venue, match.referee] == ["Junior C", "Venue 1", "Referee 1"])
    #expect(match.halfLength == 35)
    #expect(match.extraHalfLength == 10)
    #expect(match.liveShareID == "abc")
}

// MARK: - Panels

@Test func panelsKeepTheirJerseyNumbers() throws {
    let result = try PWAImporter.convert(oneMatch(panels: """
        [{"id":"p","name":"Seniors","createdDate":"2025-08-08T11:53:07.915Z",
          "players":[{"id":"x","name":"Ciarán","jerseyNumber":3},{"id":"y","name":"","jerseyNumber":1},{"id":"z","name":"Dup","jerseyNumber":3}]}]
        """))
    let panel = try #require(result.panels.first)
    #expect(panel.legacyID == "p")
    let created = try #require(panel.createdAt)
    #expect(abs(created.timeIntervalSince1970 - 1_754_653_987.915) < 0.001)
    #expect(panel.slots.count == 30)
    #expect(panel.slots[2].name == "Ciarán")
    // The duplicate number 3 drops into the first free slot (2).
    #expect(panel.slots[1].name == "Dup")
    #expect(panel.slots.filter { $0.name != nil }.count == 2)
}

@Test func legacyPanelsFillFromOneInStoredOrder() throws {
    let result = try PWAImporter.convert(oneMatch(panels: #"[{"id":"p","name":"Old","players":[{"id":"x","name":"First"},{"id":"y","name":"Second"}]}]"#))
    let panel = try #require(result.panels.first)
    #expect(panel.slots.prefix(3).map(\.name) == ["First", "Second", nil])
    #expect(panel.createdAt == nil)
}

@Test func namesBeyondThirtyAreReported() throws {
    let players = (1...32).map { #"{"id":"p\#($0)","name":"Player \#($0)"}"# }.joined(separator: ",")
    let result = try PWAImporter.convert(oneMatch(panels: #"[{"id":"p","name":"Big","players":[\#(players)]}]"#))
    #expect(result.panels[0].slots.last?.name == "Player 30")
    #expect(result.warnings.count == 1)
    #expect(result.warnings[0].contains("Player 31, Player 32"))
}

@Test func lastSelectedPanelsPointAtTheImportedPanels() throws {
    let result = try PWAImporter.convert(oneMatch(
        panels: #"[{"id":"p","name":"Seniors","players":[]}]"#,
        lastSelected: #"{"1754435709770-961121-team2":"p","1754435709770-961121-team1":"gone","other-team1":"p"}"#
    ))
    #expect(result.matches[0].team2.lastPanelID == result.panels[0].id)
    #expect(result.matches[0].team1.lastPanelID == nil)
}

@Test func skippedPanelsAreStillLinkedByTheirExistingID() throws {
    let existing = PanelID()
    let result = try PWAImporter.convert(
        oneMatch(panels: #"[{"id":"p","name":"Seniors","players":[]}]"#, lastSelected: #"{"1754435709770-961121-team1":"p"}"#),
        existingPanels: ["p": existing]
    )
    #expect(result.panels.isEmpty)
    #expect(result.skippedPanelIDs == ["p"])
    #expect(result.matches[0].team1.lastPanelID == existing)
}
