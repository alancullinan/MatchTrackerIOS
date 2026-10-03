import MatchCore
import SwiftData
import SwiftUI

/// Every player panel: a squad's names by number, ready to import into a team
/// before throw-in. The Panels tab.
struct PanelListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: PanelList.sortOrder) private var storedPanels: [StoredPanel]

    @State private var panelToEdit: PlayerPanel?
    @State private var isAddingPanel = false
    @State private var panelToDelete: StoredPanel?
    @State private var deleteError: String?

    var body: some View {
        List(storedPanels) { stored in
            row(stored)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { panelToDelete = stored }
                }
        }
        .navigationTitle("Panels")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Panel", systemImage: "plus") { isAddingPanel = true }
            }
        }
        .sheet(isPresented: $isAddingPanel) {
            PanelEditor(panel: nil)
        }
        .sheet(item: $panelToEdit) { panel in
            PanelEditor(panel: panel)
        }
        .overlay {
            if storedPanels.isEmpty {
                ContentUnavailableView {
                    Label("No Panels Yet", systemImage: "person.3")
                } description: {
                    Text("A panel is a squad's names by number. Import one into a team before throw-in, instead of typing the names each match.")
                } actions: {
                    Button("New Panel") { isAddingPanel = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .confirmationDialog(
            "Delete \(panelToDelete?.name ?? "this panel")?",
            isPresented: Binding(get: { panelToDelete != nil }, set: { if !$0 { panelToDelete = nil } }),
            titleVisibility: .visible,
            presenting: panelToDelete
        ) { stored in
            Button("Delete Panel", role: .destructive) { delete(stored) }
        } message: { _ in
            Text("Matches keep the names already imported from it. This can't be undone.")
        }
        .alert(
            "Couldn't Delete the Panel",
            isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    @ViewBuilder
    private func row(_ stored: StoredPanel) -> some View {
        if let panel = try? stored.panel() {
            Button { panelToEdit = panel } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(panel.name).font(.headline)
                    Text(PanelList.summary(panel))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            // Saved by a newer version of the app: never opened for editing, so never overwritten.
            VStack(alignment: .leading, spacing: 2) {
                Text(stored.name).font(.headline)
                Label("Can't be read by this version", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func delete(_ stored: StoredPanel) {
        do {
            try PanelList.delete(stored, from: context)
        } catch {
            context.rollback()
            deleteError = error.localizedDescription
        }
        panelToDelete = nil
    }
}

#if DEBUG
#Preview("Panels", traits: .sampleMatches) {
    NavigationStack { PanelListView() }
}

#Preview("No panels", traits: .emptyStore) {
    NavigationStack { PanelListView() }
}
#endif
