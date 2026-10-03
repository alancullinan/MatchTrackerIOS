import Foundation
import MatchCore
import SwiftData

/// The panel list's rules, kept out of the view so they can be tested.
enum PanelList {
    /// By name, as Finder sorts ("U14" before "U16", ignoring case).
    static let sortOrder = [SortDescriptor(\StoredPanel.name, comparator: .localizedStandard)]

    /// Saves an edited or new panel straight away.
    static func save(_ panel: PlayerPanel, in context: ModelContext) throws {
        try context.store(panel)
        try context.save()
    }

    /// Deletes a panel and saves straight away, so it can't come back. Matches
    /// keep their players; a team whose last panel this was just stops offering it.
    static func delete(_ stored: StoredPanel, from context: ModelContext) throws {
        context.delete(stored)
        try context.save()
    }

    /// "12 of 30 named", or "No names yet".
    static func summary(_ panel: PlayerPanel) -> String {
        panel.namedCount == 0 ? "No names yet · \(panel.slots.count) players"
            : "\(panel.namedCount) of \(panel.slots.count) named"
    }
}
