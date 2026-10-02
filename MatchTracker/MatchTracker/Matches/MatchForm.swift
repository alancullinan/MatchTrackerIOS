import Foundation
import MatchCore
import SwiftData

/// The match form's rules, kept out of the view so they can be tested.
enum MatchForm {
    enum SaveError: LocalizedError {
        case matchNotFound

        var errorDescription: String? {
            "The match is no longer on this device. It may have been deleted."
        }
    }

    /// Details for a new match: the given code, starting now.
    static func newDetails(matchType: MatchType, now: Date) -> MatchDetails {
        MatchDetails(matchType: matchType, date: now)
    }

    /// Saves `details` as a new match, or into the stored match with id
    /// `editing`, and saves the store straight away. Returns the saved match,
    /// or `nil` if the details were refused (see `Match.apply(_:)`), in which
    /// case nothing is stored.
    ///
    /// An edit is applied to the match as stored now, not as it was when the
    /// form opened, so events recorded in the meantime are kept.
    @discardableResult
    static func save(_ details: MatchDetails, editing: MatchID?, in context: ModelContext) throws -> Match? {
        let match: Match
        if let editing {
            guard let stored = try context.storedMatch(id: editing) else { throw SaveError.matchNotFound }
            var current = try stored.match()
            guard current.apply(details) else { return nil }
            match = current
        } else {
            guard let new = Match.new(details) else { return nil }
            match = new
        }
        try context.store(match)
        try context.save()
        return match
    }
}
