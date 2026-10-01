import Foundation
import Testing
@testable import MatchCore

// Expected values are copied from the PWA's script.js; order matters for MatchPeriod.

@Test func matchPeriodRawValuesInPlayOrder() {
    #expect(MatchPeriod.allCases.map(\.rawValue) == [
        "Not Started", "1st Half", "Half Time", "2nd Half", "Full Time",
        "Extra Time 1st Half", "Extra Time Half Time", "Extra Time 2nd Half", "Match Over",
    ])
}

@Test func matchTypeRawValues() {
    #expect(MatchType.allCases.map(\.rawValue) == ["football", "hurling", "ladiesFootball", "camogie"])
}

@Test func eventTypeRawValues() {
    #expect(EventType.allCases.map(\.rawValue) == [
        "shot", "substitution", "kickout", "card", "foulConceded", "note", "periodEnd",
    ])
}

@Test func shotOutcomeRawValues() {
    #expect(ShotOutcome.allCases.map(\.rawValue) == [
        "goal", "point", "twoPointer", "wide", "saved", "droppedShort", "offPost",
    ])
}

@Test func shotTypeRawValues() {
    #expect(ShotType.allCases.map(\.rawValue) == [
        "fromPlay", "free", "penalty", "fortyFive", "sixtyFive", "sideline", "mark",
    ])
}

@Test func cardTypeRawValues() {
    #expect(CardType.allCases.map(\.rawValue) == ["yellow", "red", "black"])
}

@Test func foulOutcomeRawValues() {
    #expect(FoulOutcome.allCases.map(\.rawValue) == ["free", "penalty"])
}

@Test func enumsEncodeAsPWAStrings() throws {
    let data = try JSONEncoder().encode([MatchPeriod.extraTimeFirstHalf])
    #expect(String(decoding: data, as: UTF8.self) == #"["Extra Time 1st Half"]"#)
}

@Test func enumsDecodeFromPWAStrings() throws {
    let json = Data(#"["Half Time", "Match Over"]"#.utf8)
    #expect(try JSONDecoder().decode([MatchPeriod].self, from: json) == [.halfTime, .matchOver])
    #expect(try JSONDecoder().decode([ShotOutcome].self, from: Data(#"["twoPointer"]"#.utf8)) == [.twoPointer])
}
