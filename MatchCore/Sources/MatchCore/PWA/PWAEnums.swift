// The PWA's own enum strings, exactly as its backups store them. Only the PWA
// types and the importer use these; the app's enums in Model/ are independent
// and can change without touching PWA backups. `native` converts each case.

public enum PWAPeriod: String, Codable, Sendable, CaseIterable {
    case notStarted = "Not Started"
    case firstHalf = "1st Half"
    case halfTime = "Half Time"
    case secondHalf = "2nd Half"
    case fullTime = "Full Time"
    case extraTimeFirstHalf = "Extra Time 1st Half"
    case extraTimeHalfTime = "Extra Time Half Time"
    case extraTimeSecondHalf = "Extra Time 2nd Half"
    case matchOver = "Match Over"

    var native: MatchPeriod {
        switch self {
        case .notStarted: .notStarted
        case .firstHalf: .firstHalf
        case .halfTime: .halfTime
        case .secondHalf: .secondHalf
        case .fullTime: .fullTime
        case .extraTimeFirstHalf: .extraTimeFirstHalf
        case .extraTimeHalfTime: .extraTimeHalfTime
        case .extraTimeSecondHalf: .extraTimeSecondHalf
        case .matchOver: .fullTimeAfterExtraTime
        }
    }
}

public enum PWAMatchType: String, Codable, Sendable, CaseIterable {
    case football, hurling, ladiesFootball, camogie

    var native: MatchType {
        switch self {
        case .football: .football
        case .hurling: .hurling
        case .ladiesFootball: .ladiesFootball
        case .camogie: .camogie
        }
    }
}

public enum PWAEventType: String, Codable, Sendable, CaseIterable {
    case shot, substitution, kickout, card, foulConceded, note, periodEnd
}

public enum PWAShotOutcome: String, Codable, Sendable, CaseIterable {
    case goal, point, twoPointer, wide, saved, droppedShort, offPost

    var native: ShotOutcome {
        switch self {
        case .goal: .goal
        case .point: .point
        case .twoPointer: .twoPointer
        case .wide: .wide
        case .saved: .saved
        case .droppedShort: .droppedShort
        case .offPost: .offPost
        }
    }
}

public enum PWAShotType: String, Codable, Sendable, CaseIterable {
    case fromPlay, free, penalty, fortyFive, sixtyFive, sideline, mark

    var native: ShotType {
        switch self {
        case .fromPlay: .fromPlay
        case .free: .free
        case .penalty: .penalty
        case .fortyFive: .fortyFive
        case .sixtyFive: .sixtyFive
        case .sideline: .sideline
        case .mark: .mark
        }
    }
}

public enum PWACardType: String, Codable, Sendable, CaseIterable {
    case yellow, red, black

    var native: CardType {
        switch self {
        case .yellow: .yellow
        case .red: .red
        case .black: .black
        }
    }
}

public enum PWAFoulOutcome: String, Codable, Sendable, CaseIterable {
    case free, penalty

    var native: FoulOutcome {
        switch self {
        case .free: .free
        case .penalty: .penalty
        }
    }
}
