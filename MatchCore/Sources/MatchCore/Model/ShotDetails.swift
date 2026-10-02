import Foundation

extension ShotOutcome {
    /// What a recorded shot's outcome can be changed to on the scorer sheet:
    /// a point and a two-pointer swap (where two-pointers exist), misses swap
    /// among themselves, and a goal stays a goal.
    public func alternatives(in matchType: MatchType) -> [ShotOutcome] {
        switch self {
        case .goal:
            [.goal]
        case .point, .twoPointer:
            matchType.allowsTwoPointers ? [.point, .twoPointer] : [.point]
        case .wide, .saved, .droppedShort, .offPost:
            [.wide, .saved, .droppedShort, .offPost]
        }
    }
}

extension ShotType {
    /// How a shot can be taken in `matchType`, in the order the scorer sheet
    /// offers them. Football codes have the 45; hurling and camogie the 65.
    public static func options(for matchType: MatchType) -> [ShotType] {
        switch matchType {
        case .football, .ladiesFootball: [.fromPlay, .free, .fortyFive, .penalty, .mark, .sideline]
        case .hurling, .camogie: [.fromPlay, .free, .sixtyFive, .penalty, .mark, .sideline]
        }
    }

    /// The name to show.
    public var displayName: String {
        switch self {
        case .fromPlay: "From play"
        case .free: "Free"
        case .penalty: "Penalty"
        case .fortyFive: "45"
        case .sixtyFive: "65"
        case .sideline: "Sideline"
        case .mark: "Mark"
        }
    }
}

extension Match {
    public func event(_ id: EventID) -> MatchEvent? {
        events.first { $0.id == id }
    }

    /// Sets a recorded shot's details: its outcome (within
    /// `ShotOutcome.alternatives(in:)`), how it was taken, the player (one of
    /// that team's, or `nil`) and its note (blank becomes `nil`). Its team,
    /// period and time are kept. Returns `false`, changing nothing, if the
    /// event isn't a shot or a detail doesn't fit.
    @discardableResult
    public mutating func updateShot(
        _ id: EventID,
        outcome: ShotOutcome,
        type: ShotType,
        player: PlayerID?,
        note: String?
    ) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }),
              case .shot(let side, _, let current, _) = events[index].kind,
              current.alternatives(in: matchType).contains(outcome),
              player.map({ self[side].player($0) != nil }) ?? true
        else { return false }
        events[index].kind = .shot(side: side, player: player, outcome: outcome, type: type)
        events[index].note = MatchEvent.cleanNote(note)
        return true
    }

    /// Deletes an event and returns it. A period end can't be deleted (it is
    /// part of the match's progress; see `undoLastEvent()`), so for one, or an
    /// unknown id, returns `nil` and changes nothing.
    @discardableResult
    public mutating func deleteEvent(_ id: EventID) -> MatchEvent? {
        guard let index = events.firstIndex(where: { $0.id == id }), events[index].kind != .periodEnd else {
            return nil
        }
        return events.remove(at: index)
    }
}
