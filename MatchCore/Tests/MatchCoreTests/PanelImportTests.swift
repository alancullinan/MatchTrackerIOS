import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func newMatch() -> Match {
    Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: t0)
}

/// A panel with names in slots 1 and 3, and `extra` added slots.
private func panel(extra: Int = 0) -> PlayerPanel {
    var panel = PlayerPanel.empty(name: "Seniors")
    var slots = panel.slots
    slots[0].name = "Keeper"
    slots[2].name = "Full Back"
    for _ in 0..<extra { slots.append(PanelSlot(jerseyNumber: slots.count + 1, name: "Sub")) }
    panel.update(name: "Seniors", slots: slots)
    return panel
}

// #expect can't call a mutating method itself, so each step's result is kept first.

@Test func importingAPanelCopiesNamesByNumberAndKeepsPlayerIDs() {
    var match = newMatch()
    var players = match.team1.players
    players[1].name = "Old Name"
    match.updateRoster(.team1, players: players)
    let ids = match.team1.players.map(\.id)

    let imported = match.importPanel(panel(), into: .team1)
    #expect(imported)
    #expect(match.team1.players.map(\.id) == ids)
    #expect(match.team1.players[0].name == "Keeper")
    #expect(match.team1.players[1].name == nil)
    #expect(match.team1.players[2].name == "Full Back")
    #expect(match.team2.players.allSatisfy { $0.name == nil })
}

@Test func importingAPanelRemembersItAsTheTeamsLastPanel() {
    var match = newMatch()
    let seniors = panel()
    match.importPanel(seniors, into: .team2)
    #expect(match.team2.lastPanelID == seniors.id)
    #expect(match.team1.lastPanelID == nil)
}

@Test func aLargerPanelAddsPlayersAndASmallerOneRemovesAddedOnes() {
    var match = newMatch()
    let grown = match.importPanel(panel(extra: 3), into: .team1)
    #expect(grown)
    #expect(match.team1.players.map(\.jerseyNumber) == Array(1...33))
    #expect(match.team1.players[32].name == "Sub")

    let shrunk = match.importPanel(panel(), into: .team1)
    #expect(shrunk)
    #expect(match.team1.players.count == 30)
}

@Test func aPanelCanOnlyBeImportedBeforeThrowIn() {
    var match = newMatch()
    match.start(at: t0)
    #expect(!match.canImportPanel)
    let imported = match.importPanel(panel(), into: .team1)
    #expect(!imported)
    #expect(match.team1.players.allSatisfy { $0.name == nil })
    #expect(match.team1.lastPanelID == nil)
}

@Test func anEditedSheetFromAPanelIsSavedWithThePanel() {
    var match = newMatch()
    let seniors = panel()
    var players = match.team1.players(importing: seniors)
    players[5].name = "Late Change"

    let updated = match.updateRoster(.team1, players: players, fromPanel: seniors.id)
    #expect(updated)
    #expect(match.team1.players[5].name == "Late Change")
    #expect(match.team1.lastPanelID == seniors.id)
}

@Test func anInvalidSheetFromAPanelChangesNothing() {
    var match = newMatch()
    let seniors = panel()
    let players = Array(match.team1.players(importing: seniors).dropLast())
    let updated = match.updateRoster(.team1, players: players, fromPanel: seniors.id)
    #expect(!updated)
    #expect(match.team1.lastPanelID == nil)
}
