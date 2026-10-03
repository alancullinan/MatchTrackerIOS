import MatchCore
import SwiftData
import SwiftUI

/// Picks a panel to import into a team, with the suggested one first (see
/// `PanelSuggestion`). Picking hands the panel back and closes.
struct PanelPicker: View {
    let team: Team
    let matchID: MatchID
    let onPick: (PlayerPanel) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: PanelList.sortOrder) private var storedPanels: [StoredPanel]
    @Query private var storedMatches: [StoredMatch]

    /// Panels that can be read; one saved by a newer version is left out.
    private var panels: [PlayerPanel] { storedPanels.compactMap { try? $0.panel() } }

    private var suggested: PlayerPanel? {
        let panels = panels
        let id = PanelSuggestion.suggested(
            for: team,
            pastTeams: PanelSuggestion.pastTeams(storedMatches, excluding: matchID),
            panels: Set(panels.map(\.id))
        )
        return panels.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            List {
                if let suggested {
                    Section("Suggested") { row(suggested) }
                }
                Section {
                    ForEach(panels) { row($0) }
                } header: {
                    if suggested != nil { Text("All Panels") }
                } footer: {
                    if !panels.isEmpty {
                        Text("The panel's names replace this team's, number by number.")
                    }
                }
            }
            .overlay {
                if panels.isEmpty {
                    ContentUnavailableView(
                        "No Panels Yet",
                        systemImage: "person.3",
                        description: Text("Make one under Panels on the match list, or use Save as New Panel on a team sheet.")
                    )
                }
            }
            .navigationTitle("Import Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ panel: PlayerPanel) -> some View {
        Button {
            onPick(panel)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(panel.name).font(.headline)
                Text(PanelList.summary(panel)).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
