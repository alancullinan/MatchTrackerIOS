import Foundation

// The app's own enums. They are stored by case name, so a case name is
// permanent once matches are saved: add cases, never rename one. Names shown
// to people come from `displayName`, not from these names.

/// Match periods, declared in play order: `allCases` is the order periods are played in.
public enum MatchPeriod: String, Codable, Sendable, CaseIterable {
    case notStarted
    case firstHalf
    case halfTime
    case secondHalf
    case fullTime
    case extraTimeFirstHalf
    case extraTimeHalfTime
    case extraTimeSecondHalf
    case fullTimeAfterExtraTime
}

public enum MatchType: String, Codable, Sendable, CaseIterable {
    case football
    case hurling
    case ladiesFootball
    case camogie
}

public enum EventType: String, Codable, Sendable, CaseIterable {
    case shot
    case substitution
    case kickout
    case card
    case foul
    case note
    case periodEnd
}

public enum ShotOutcome: String, Codable, Sendable, CaseIterable {
    case goal
    case point
    case twoPointer
    case wide
    case saved
    case droppedShort
    case offPost
}

public enum ShotType: String, Codable, Sendable, CaseIterable {
    case fromPlay
    case free
    case penalty
    case fortyFive
    case sixtyFive
    case sideline
    case mark
}

public enum CardType: String, Codable, Sendable, CaseIterable {
    case yellow
    case red
    case black
}

public enum FoulOutcome: String, Codable, Sendable, CaseIterable {
    case free
    case penalty
}
