import Foundation
import MatchCore
import SwiftData
import Testing
@testable import MatchTracker

@MainActor
struct PanelListTests {
    let context: ModelContext

    init() throws {
        context = ModelContext(try Store.container(inMemory: true))
    }

    private func names() throws -> [String] {
        try context.fetch(FetchDescriptor<StoredPanel>(sortBy: PanelList.sortOrder)).map(\.name)
    }

    @Test func panelsAreSortedByNameAsFinderSortsThem() throws {
        for name in ["u16 Boys", "U14 Girls", "Seniors", "U8"] {
            try PanelList.save(.empty(name: name), in: context)
        }
        #expect(try names() == ["Seniors", "U8", "U14 Girls", "u16 Boys"])
    }

    @Test func savingAnEditedPanelUpdatesItsRecord() throws {
        var panel = PlayerPanel.empty(name: "Seniors")
        try PanelList.save(panel, in: context)
        var slots = panel.slots
        slots[0].name = "Aoife Casey"
        panel.update(name: "Senior Ladies", slots: slots)
        try PanelList.save(panel, in: context)

        #expect(try names() == ["Senior Ladies"])
        let read = try #require(try context.storedPanel(id: panel.id)).panel()
        #expect(read == panel)
        #expect(!context.hasChanges)
    }

    @Test func aDeletedPanelIsGoneStraightAway() throws {
        let panel = PlayerPanel.empty(name: "Seniors")
        try PanelList.save(panel, in: context)
        try PanelList.delete(try #require(try context.storedPanel(id: panel.id)), from: context)
        #expect(try names().isEmpty)
        #expect(!context.hasChanges)
    }

    @Test func theSummaryCountsNamedPlayers() {
        var panel = PlayerPanel.empty(name: "Seniors")
        #expect(PanelList.summary(panel) == "No names yet · 30 players")
        var slots = panel.slots
        slots[3].name = "Niamh Ryan"
        slots.append(PanelSlot(jerseyNumber: 31, name: "Jack Moran"))
        panel.update(name: "Seniors", slots: slots)
        #expect(PanelList.summary(panel) == "2 of 31 named")
    }
}
