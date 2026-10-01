import Foundation

// Raw values are the PWA's exact strings (script.js), so exports round-trip.

/// Match periods, declared in play order: `allCases` is the order periods are played in.
public enum MatchPeriod: String, Codable, Sendable, CaseIterable {
    case notStarted = "Not Started"
    case firstHalf = "1st Half"
    case halfTime = "Half Time"
    case secondHalf = "2nd Half"
    case fullTime = "Full Time"
    case extraTimeFirstHalf = "Extra Time 1st Half"
    case extraTimeHalfTime = "Extra Time Half Time"
    case extraTimeSecondHalf = "Extra Time 2nd Half"
    case matchOver = "Match Over"
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
    case foulConceded
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
