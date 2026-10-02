import Foundation
import MatchCore
import Observation
import SwiftData

/// The match being tracked on the match screen. Every change goes through
/// here: it is applied with MatchCore, saved straight away, and remembered so
/// it can be undone. Kept out of the view so it can be tested.
@MainActor
@Observable
final class MatchSession {
    /// What the screen can do to the match.
    enum Action: Equatable {
        case nextStep
        case pause
        case resume
        case score(TeamSide, ShotOutcome)
        /// A wide; the scorer sheet then offers saved, short or post instead.
        case miss(TeamSide)
    }

    /// The change that Undo would reverse.
    enum Undoable: Equatable {
        case event(EventID)
        case periodStart(MatchPeriod)
    }

    private(set) var match: Match
    /// Set after a change that can be undone; cleared by `clearUndo()` after a few seconds.
    private(set) var undoable: Undoable?
    /// Goes up with every change, to trigger haptics.
    private(set) var changeCount = 0
    /// The shot whose details the scorer sheet is showing, if it is open.
    var scorerSheetEvent: EventID?
    var saveError: String?

    private let context: ModelContext

    init(match: Match, context: ModelContext) {
        self.match = match
        self.context = context
    }

    /// Applies `action` at `now`. Returns `false`, changing nothing, if it
    /// doesn't apply (e.g. a flag tapped while the ball isn't in play).
    @discardableResult
    func perform(_ action: Action, at now: Date) -> Bool {
        var changed = match
        let applied: Bool
        var newUndoable: Undoable?

        switch action {
        case .nextStep:
            let step = changed.nextStep
            applied = changed.takeNextStep(at: now)
            switch step {
            case .start(let period): newUndoable = .periodStart(period)
            case .end: newUndoable = changed.events.last.map { .event($0.id) }
            case nil: break
            }
        case .pause:
            applied = changed.pause(at: now)
        case .resume:
            applied = changed.clock.period.isPlaying && changed.start(at: now)
        case .score(let side, let outcome):
            let event = changed.record(.shot(side: side, player: nil, outcome: outcome, type: .fromPlay), at: now)
            applied = event != nil
            newUndoable = event.map { .event($0.id) }
        case .miss(let side):
            let event = changed.record(.shot(side: side, player: nil, outcome: .wide, type: .fromPlay), at: now)
            applied = event != nil
            newUndoable = event.map { .event($0.id) }
        }

        guard applied, save(changed) else { return false }
        if action != .pause && action != .resume { undoable = newUndoable }
        // The tap has counted the shot; now ask for its details. A miss always
        // asks (wide, saved, short or post); a score only if the team asks for scorers.
        if case .event(let id) = newUndoable {
            switch action {
            case .score(let side, _) where match[side].asksForScorers: scorerSheetEvent = id
            case .miss: scorerSheetEvent = id
            default: break
            }
        }
        return true
    }

    /// Saves the details picked on the scorer sheet. See `Match.updateShot`.
    @discardableResult
    func updateShot(_ id: EventID, outcome: ShotOutcome, type: ShotType, player: PlayerID?, note: String?) -> Bool {
        var changed = match
        guard changed.updateShot(id, outcome: outcome, type: type, player: player, note: note) else { return false }
        return save(changed)
    }

    /// Deletes an event, e.g. "Undo point" on the scorer sheet.
    @discardableResult
    func deleteEvent(_ id: EventID) -> Bool {
        var changed = match
        guard changed.deleteEvent(id) != nil else { return false }
        if undoable == .event(id) { undoable = nil }
        return save(changed)
    }

    /// Turns the scorer sheet on or off for one team's scores.
    func setAsksForScorers(_ asks: Bool, for side: TeamSide) {
        var changed = match
        changed[side].asksForScorers = asks
        _ = save(changed)
    }

    /// Reverses `undoable`. Returns `false`, changing nothing, if there is
    /// nothing to undo or the match has moved on since.
    @discardableResult
    func undo() -> Bool {
        guard let undoable else { return false }
        var changed = match
        let undone: Bool
        switch undoable {
        case .event(let id):
            undone = changed.events.last?.id == id && changed.undoLastEvent() != nil
        case .periodStart(let period):
            undone = changed.clock.period == period && changed.undoPeriodStart()
        }
        self.undoable = nil
        return undone && save(changed)
    }

    func clearUndo() {
        undoable = nil
    }

    /// Reads the match back from the store, e.g. after it was edited elsewhere.
    func reload() {
        guard let stored = try? context.storedMatch(id: match.id), let fresh = try? stored.match() else { return }
        match = fresh
    }

    private func save(_ changed: Match) -> Bool {
        do {
            try context.store(changed)
            try context.save()
            match = changed
            changeCount += 1
            return true
        } catch {
            context.rollback()
            saveError = error.localizedDescription
            return false
        }
    }
}
