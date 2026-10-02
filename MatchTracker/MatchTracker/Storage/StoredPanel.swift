import Foundation
import MatchCore
import SwiftData

/// A player panel as SwiftData stores it; `MatchCore.PlayerPanel` is the model
/// the app works with. The 30 slots are encoded as JSON in slot order, so empty
/// slots are kept and the order never changes.
///
/// Kept CloudKit-compatible, like `StoredMatch`.
@Model
final class StoredPanel {
    var id: UUID = UUID()
    var legacyID: String?
    var name: String = ""
    var createdAt: Date?
    /// `[PanelSlot]` as JSON.
    var slots: Data = Data()

    init(_ panel: PlayerPanel) throws {
        id = panel.id.uuid
        try update(from: panel)
    }

    /// Writes `panel` into this record, leaving unchanged fields alone.
    func update(from panel: PlayerPanel) throws {
        let slots = try StoredCoding.encode(panel.slots)
        if legacyID != panel.legacyID { legacyID = panel.legacyID }
        if name != panel.name { name = panel.name }
        if createdAt != panel.createdAt { createdAt = panel.createdAt }
        if self.slots != slots { self.slots = slots }
    }

    /// The stored panel. Throws rather than guess if the slots can't be read.
    func panel() throws -> PlayerPanel {
        PlayerPanel(
            id: PanelID(id),
            legacyID: legacyID,
            name: name,
            createdAt: createdAt,
            slots: try StoredCoding.decode([PanelSlot].self, slots, field: "slots")
        )
    }
}
