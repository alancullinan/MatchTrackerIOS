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
        }

        guard applied, save(changed) else { return false }
        if action != .pause && action != .resume { undoable = newUndoable }
        return true
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
