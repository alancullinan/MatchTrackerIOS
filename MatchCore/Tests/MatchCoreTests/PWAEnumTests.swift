import Foundation
import Testing
@testable import MatchCore

// Expected values are copied from the PWA's script.js; order matters for PWAPeriod.

@Test func matchPeriodRawValuesInPlayOrder() {
    #expect(PWAPeriod.allCases.map(\.rawValue) == [
        "Not Started", "1st Half", "Half Time", "2nd Half", "Full Time",
        "Extra Time 1st Half", "Extra Time Half Time", "Extra Time 2nd Half", "Match Over",
    ])
}

@Test func matchTypeRawValues() {
    #expect(PWAMatchType.allCases.map(\.rawValue) == ["football", "hurling", "ladiesFootball", "camogie"])
}

@Test func eventTypeRawValues() {
    #expect(PWAEventType.allCases.map(\.rawValue) == [
        "shot", "substitution", "kickout", "card", "foulConceded", "note", "periodEnd",
    ])
}

@Test func shotOutcomeRawValues() {
    #expect(PWAShotOutcome.allCases.map(\.rawValue) == [
        "goal", "point", "twoPointer", "wide", "saved", "droppedShort", "offPost",
    ])
}

@Test func shotTypeRawValues() {
    #expect(PWAShotType.allCases.map(\.rawValue) == [
        "fromPlay", "free", "penalty", "fortyFive", "sixtyFive", "sideline", "mark",
    ])
}

@Test func cardTypeRawValues() {
    #expect(PWACardType.allCases.map(\.rawValue) == ["yellow", "red", "black"])
}

@Test func foulOutcomeRawValues() {
    #expect(PWAFoulOutcome.allCases.map(\.rawValue) == ["free", "penalty"])
}

@Test func enumsEncodeAsPWAStrings() throws {
    let data = try JSONEncoder().encode([PWAPeriod.extraTimeFirstHalf])
    #expect(String(decoding: data, as: UTF8.self) == #"["Extra Time 1st Half"]"#)
}

@Test func enumsDecodeFromPWAStrings() throws {
    let json = Data(#"["Half Time", "Match Over"]"#.utf8)
    #expect(try JSONDecoder().decode([PWAPeriod].self, from: json) == [.halfTime, .matchOver])
    #expect(try JSONDecoder().decode([PWAShotOutcome].self, from: Data(#"["twoPointer"]"#.utf8)) == [.twoPointer])
}

@Test func pwaEnumsConvertToNativeCases() {
    #expect(PWAPeriod.allCases.map(\.native) == MatchPeriod.allCases)
    #expect(PWAPeriod.matchOver.native == .fullTimeAfterExtraTime)
    #expect(PWAMatchType.allCases.map(\.native) == MatchType.allCases)
    #expect(PWAShotOutcome.allCases.map(\.native) == ShotOutcome.allCases)
    #expect(PWAShotType.allCases.map(\.native) == ShotType.allCases)
    #expect(PWACardType.allCases.map(\.native) == CardType.allCases)
    #expect(PWAFoulOutcome.allCases.map(\.native) == FoulOutcome.allCases)
}
