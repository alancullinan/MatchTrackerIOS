import Foundation
import MatchCore
import SwiftData

/// The app's one persistent store. It stays on the device until iCloud is
/// turned on in Phase 4, when `cloudKitDatabase` changes to `.automatic`.
enum Store {
    static let models: [any PersistentModel.Type] = [StoredMatch.self, StoredPanel.self]

    static func container(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(models),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }
}

/// Saving and loading MatchCore values. Ids are unique in code, not by the
/// schema (CloudKit doesn't allow unique attributes): storing a value updates
/// the record with its id, or inserts one if there is none.
extension ModelContext {
    func storedMatch(id: MatchID) throws -> StoredMatch? {
        let uuid = id.uuid
        var descriptor = FetchDescriptor<StoredMatch>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    /// Inserts `match`, or updates the record that already has its id.
    @discardableResult
    func store(_ match: Match) throws -> StoredMatch {
        if let existing = try storedMatch(id: match.id) {
            try existing.update(from: match)
            return existing
        }
        let stored = try StoredMatch(match)
        insert(stored)
        return stored
    }

    func storedPanel(id: PanelID) throws -> StoredPanel? {
        let uuid = id.uuid
        var descriptor = FetchDescriptor<StoredPanel>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    /// Inserts `panel`, or updates the record that already has its id.
    @discardableResult
    func store(_ panel: PlayerPanel) throws -> StoredPanel {
        if let existing = try storedPanel(id: panel.id) {
            try existing.update(from: panel)
            return existing
        }
        let stored = try StoredPanel(panel)
        insert(stored)
        return stored
    }
}
