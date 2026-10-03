import Foundation
import Testing
@testable import MatchCore

/// `panel`'s slots with `extra` more added after the last number.
private func withExtras(_ panel: PlayerPanel, _ extra: Int) -> [PanelSlot] {
    var slots = panel.slots
    for _ in 0..<extra {
        slots.append(PanelSlot(jerseyNumber: slots.count + 1))
    }
    return slots
}

// #expect can't call a mutating method itself, so each step's result is kept first.

@Test func aPanelStartsWith30SlotsAndCanGrowTo40() {
    var panel = PlayerPanel.empty(name: "Seniors")
    #expect(panel.slots.count == 30)
    #expect(panel.nextExtraSlot()?.jerseyNumber == 31)

    let grown = panel.update(name: "Seniors", slots: withExtras(panel, 10))
    #expect(grown)
    #expect(panel.slots.map(\.jerseyNumber) == Array(1...40))
    #expect(panel.nextExtraSlot() == nil)
}

@Test func aPanelCanBeRenamedAndItsSlotsNamed() {
    var panel = PlayerPanel.empty(name: "Seniors")
    var slots = panel.slots
    slots[0].name = "  Aoife Casey "
    slots[1].name = "   "

    let updated = panel.update(name: " Senior Ladies ", slots: slots)
    #expect(updated)
    #expect(panel.name == "Senior Ladies")
    #expect(panel.slots[0].name == "Aoife Casey")
    #expect(panel.slots[1].name == nil)
    #expect(panel.namedCount == 1)
}

@Test func aPanelNeedsAName() {
    var panel = PlayerPanel.empty(name: "Seniors")
    let updated = panel.update(name: "  ", slots: panel.slots)
    #expect(!updated)
    #expect(panel.name == "Seniors")
}

@Test func aPanelKeepsAtLeast30Slots() {
    var panel = PlayerPanel.empty(name: "Seniors")
    let updated = panel.update(name: "Seniors", slots: Array(panel.slots.dropLast()))
    #expect(!updated)
    #expect(panel.slots.count == 30)
}

@Test func aPanelHasAtMost40Slots() {
    var panel = PlayerPanel.empty(name: "Seniors")
    let updated = panel.update(name: "Seniors", slots: withExtras(panel, 11))
    #expect(!updated)
    #expect(panel.slots.count == 30)
}

@Test func aPanelsNumbersRunWithoutGaps() {
    var panel = PlayerPanel.empty(name: "Seniors")
    var slots = withExtras(panel, 1)
    slots[30] = PanelSlot(jerseyNumber: 32)
    let gap = panel.update(name: "Seniors", slots: slots)
    #expect(!gap)

    var swapped = panel.slots
    swapped.swapAt(0, 1)
    let unordered = panel.update(name: "Seniors", slots: swapped)
    #expect(!unordered)
    #expect(panel.slots.map(\.jerseyNumber) == Array(1...30))
}

@Test func anAddedSlotCanBeRemovedAgain() {
    var panel = PlayerPanel.empty(name: "Seniors")
    panel.update(name: "Seniors", slots: withExtras(panel, 2))
    let removed = panel.update(name: "Seniors", slots: Array(panel.slots.dropLast()))
    #expect(removed)
    #expect(panel.slots.count == 31)
}
