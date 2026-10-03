import MatchCore
import SwiftData
import SwiftUI

/// A team's names by jersey number: the starting 15, then the subs. Players
/// 31 to 40 can be added, and an added player no event names can be removed
/// again. Editable any time, before, during or after the match: names added
/// later appear on events already recorded. Before throw-in a panel can be
/// imported; any time the names can be saved as a new panel. Nothing is saved
/// to the match until Done.
struct TeamSheetEditor: View {
    let session: MatchSession
    let side: TeamSide

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var players: [Player] = []
    @State private var loaded = false
    /// The panel imported into the sheet, remembered as the team's last panel on Done.
    @State private var importedPanel: PlayerPanel?
    @State private var picksPanel = false
    @State private var savedPanelName: String?
    @State private var panelError: String?
    @FocusState private var focused: PlayerID?

    private var team: Team { session.match[side] }
    private var hasChanges: Bool { loaded && (players != team.players || importedPanel != nil) }

    var body: some View {
        NavigationStack {
            List {
                panelSection
                Section("Starting 15") {
                    ForEach($players.filter { $0.wrappedValue.jerseyNumber <= 15 }, id: \.wrappedValue.id) { $player in
                        row($player)
                    }
                }
                Section {
                    ForEach($players.filter { $0.wrappedValue.jerseyNumber > 15 }, id: \.wrappedValue.id) { $player in
                        row($player)
                            .deleteDisabled(!canRemove(player))
                    }
                    .onDelete(perform: removeLast)
                    if let next = nextPlayer {
                        Button("Add Player \(next.jerseyNumber)", systemImage: "plus.circle.fill") {
                            players.append(next)
                            focused = next.id
                        }
                    }
                } header: {
                    Text("Subs")
                } footer: {
                    Text("Up to \(Team.maxRosterSize) players. An added player can be removed by swiping, if no event names them.")
                }
            }
            .navigationTitle(EventText.teamName(team))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        if hasChanges { session.updateRoster(side, players: players, fromPanel: importedPanel?.id) }
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $picksPanel) {
            PanelPicker(team: team, matchID: session.match.id, onPick: importPanel)
                .matchSheetAppearance()
        }
        .alert(
            "Saved as a Panel",
            isPresented: Binding(get: { savedPanelName != nil }, set: { if !$0 { savedPanelName = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text("“\(savedPanelName ?? "")” is under Panels on the match list, ready to import next time.")
        }
        .alert(
            "Couldn't Save the Panel",
            isPresented: Binding(get: { panelError != nil }, set: { if !$0 { panelError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(panelError ?? "")
        }
        // A swipe down mustn't lose names being typed; Cancel or Done closes it.
        .interactiveDismissDisabled(hasChanges)
        .onAppear {
            guard !loaded else { return }
            players = team.players
            loaded = true
        }
    }

    private var panelSection: some View {
        Section {
            if session.match.canImportPanel {
                Button("Import from Panel…", systemImage: "square.and.arrow.down") { picksPanel = true }
            }
            Button("Save as New Panel", systemImage: "square.and.arrow.up", action: saveAsPanel)
        } footer: {
            if let importedPanel {
                Text("Names from \(importedPanel.name). Done keeps them.")
            } else if !session.match.canImportPanel {
                Text("A panel can be imported before throw-in.")
            }
        }
    }

    /// Copies the panel's names into the sheet; Done saves them.
    private func importPanel(_ panel: PlayerPanel) {
        var draft = team
        draft.players = players
        players = draft.players(importing: panel)
        importedPanel = panel
    }

    /// Saves the sheet's names, as they are now, as a new panel named after the team.
    private func saveAsPanel() {
        var panel = PlayerPanel.empty(name: EventText.teamName(team), createdAt: .now)
        let slots = players.map { PanelSlot(jerseyNumber: $0.jerseyNumber, name: $0.name) }
        guard panel.update(name: panel.name, slots: slots) else { return }
        do {
            try PanelList.save(panel, in: context)
            savedPanelName = panel.name
        } catch {
            context.rollback()
            panelError = error.localizedDescription
        }
    }

    private func row(_ player: Binding<Player>) -> some View {
        HStack(spacing: 12) {
            Text("\(player.wrappedValue.jerseyNumber)")
                .font(MatchTheme.display(22, .bold))
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
            TextField("Name", text: Binding(
                get: { player.wrappedValue.name ?? "" },
                set: { player.wrappedValue.name = $0 }
            ))
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .focused($focused, equals: player.wrappedValue.id)
            .onSubmit { focusNext(after: player.wrappedValue) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(player.wrappedValue.jerseyNumber)")
    }

    /// The player "Add" would add, until the team has the most it can.
    private var nextPlayer: Player? {
        players.count < Team.maxRosterSize ? Player(jerseyNumber: players.count + 1) : nil
    }

    /// Only the last player, and only an added one no event names, so numbers stay in order.
    private func canRemove(_ player: Player) -> Bool {
        player.id == players.last?.id
            && player.jerseyNumber > Team.startingRosterSize
            && !session.match.isReferenced(player.id)
    }

    private func removeLast(_ offsets: IndexSet) {
        // Offsets are within the subs section; only its last row can be removed.
        guard let last = players.last, canRemove(last) else { return }
        players.removeLast()
    }

    private func focusNext(after player: Player) {
        guard let index = players.firstIndex(where: { $0.id == player.id }), index + 1 < players.count else {
            focused = nil
            return
        }
        focused = players[index + 1].id
    }
}

#if DEBUG
#Preview("Team sheet") {
    TeamSheetEditor(session: .preview(.secondHalf), side: .team1)
}
#endif
