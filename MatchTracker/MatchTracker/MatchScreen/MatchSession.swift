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
        /// A free conceded by the team; the sheet adds a penalty or a card.
        case foul(TeamSide)
        /// The team's kickout, as won; the sheet offers lost instead.
        case kickout(TeamSide)
        case substitution(TeamSide)
        /// A note for a team, or for the match with `nil`. Its text comes from the sheet.
        case note(TeamSide?)
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
    /// The event whose details sheet is open: the scorer sheet for a shot, or
    /// the sheet for a foul, kickout, substitution or note.
    var detailsEvent: EventID?
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
            newUndoable = record(.shot(side: side, player: nil, outcome: outcome, type: .fromPlay), in: &changed, at: now)
            applied = newUndoable != nil
        case .miss(let side):
            newUndoable = record(.shot(side: side, player: nil, outcome: .wide, type: .fromPlay), in: &changed, at: now)
            applied = newUndoable != nil
        case .foul(let side):
            newUndoable = record(.foul(side: side, player: nil, outcome: .free, card: nil), in: &changed, at: now)
            applied = newUndoable != nil
        case .kickout(let side):
            newUndoable = record(.kickout(side: side, player: nil, won: true), in: &changed, at: now)
            applied = newUndoable != nil
        case .substitution(let side):
            newUndoable = record(.substitution(side: side, off: nil, on: nil), in: &changed, at: now)
            applied = newUndoable != nil
        case .note(let side):
            newUndoable = record(.note(side: side), in: &changed, at: now)
            applied = newUndoable != nil
        }

        guard applied, save(changed) else { return false }
        if action != .pause && action != .resume { undoable = newUndoable }
        // The tap has counted the event; now ask for its details. Everything
        // but a period end asks; a score only if the team asks for scorers.
        if case .event(let id) = newUndoable {
            switch action {
            case .score(let side, _): if match[side].asksForScorers { detailsEvent = id }
            case .nextStep, .pause, .resume: break
            case .miss, .foul, .kickout, .substitution, .note: detailsEvent = id
            }
        }
        return true
    }

    private func record(_ kind: MatchEvent.Kind, in match: inout Match, at now: Date) -> Undoable? {
        match.record(kind, at: now).map { .event($0.id) }
    }

    /// Saves the details picked on the scorer sheet. See `Match.updateShot`.
    @discardableResult
    func updateShot(_ id: EventID, outcome: ShotOutcome, type: ShotType, player: PlayerID?, note: String?) -> Bool {
        update { $0.updateShot(id, outcome: outcome, type: type, player: player, note: note) }
    }

    /// Saves the details picked on the foul sheet. See `Match.updateFoul`.
    @discardableResult
    func updateFoul(_ id: EventID, outcome: FoulOutcome, card: CardType?, player: PlayerID?, note: String?) -> Bool {
        update { $0.updateFoul(id, outcome: outcome, card: card, player: player, note: note) }
    }

    /// Saves the details picked on the kickout sheet. See `Match.updateKickout`.
    @discardableResult
    func updateKickout(_ id: EventID, won: Bool, player: PlayerID?, note: String?) -> Bool {
        update { $0.updateKickout(id, won: won, player: player, note: note) }
    }

    /// Saves the players picked on the substitution sheet. See `Match.updateSubstitution`.
    @discardableResult
    func updateSubstitution(_ id: EventID, off: PlayerID?, on: PlayerID?, note: String?) -> Bool {
        update { $0.updateSubstitution(id, off: off, on: on, note: note) }
    }

    /// Saves a note's text, or deletes the note if the text is blank: a note
    /// with no text says nothing.
    @discardableResult
    func saveNote(_ id: EventID, text: String) -> Bool {
        if text.allSatisfy(\.isWhitespace) { return deleteEvent(id) }
        return update { $0.updateNote(id, text: text) }
    }

    /// Saves an edited team sheet. See `Match.updateRoster`.
    @discardableResult
    func updateRoster(_ side: TeamSide, players: [Player]) -> Bool {
        update { $0.updateRoster(side, players: players) }
    }

    /// Moves an event to another time or period. See `Match.updateTime`.
    @discardableResult
    func updateTime(_ id: EventID, period: MatchPeriod, time: Int) -> Bool {
        update { $0.updateTime(id, period: period, time: time) }
    }

    /// Moves the running clock on or back. See `Match.adjustClock`.
    @discardableResult
    func adjustClock(by seconds: Int, at now: Date) -> Bool {
        update { $0.adjustClock(by: seconds, at: now) }
    }

    private func update(_ change: (inout Match) -> Bool) -> Bool {
        var changed = match
        guard change(&changed) else { return false }
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
