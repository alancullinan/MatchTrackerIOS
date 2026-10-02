import Foundation
import Testing
@testable import MatchCore

// The app's enums are stored by case name, independent of the PWA's strings.

@Test func nativeEnumsEncodeAsCaseNames() throws {
    let data = try JSONEncoder().encode([MatchPeriod.fullTimeAfterExtraTime, .firstHalf])
    #expect(String(decoding: data, as: UTF8.self) == #"["fullTimeAfterExtraTime","firstHalf"]"#)
    #expect(try JSONDecoder().decode([MatchPeriod].self, from: data) == [.fullTimeAfterExtraTime, .firstHalf])
    #expect(String(decoding: try JSONEncoder().encode([EventType.foul]), as: UTF8.self) == #"["foul"]"#)
}

@Test func matchPeriodsAreInPlayOrder() {
    #expect(MatchPeriod.allCases == [
        .notStarted, .firstHalf, .halfTime, .secondHalf, .fullTime,
        .extraTimeFirstHalf, .extraTimeHalfTime, .extraTimeSecondHalf, .fullTimeAfterExtraTime,
    ])
}
