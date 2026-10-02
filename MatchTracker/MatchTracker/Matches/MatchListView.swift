import SwiftData
import SwiftUI

/// The home screen: every match, newest first, with search.
struct MatchListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: MatchList.sortOrder) private var storedMatches: [StoredMatch]

    @State private var searchText = ""
    @State private var matchToDelete: StoredMatch?
    @State private var deleteError: String?

    private var shownMatches: [StoredMatch] {
        storedMatches.filter { MatchList.matches($0, query: searchText) }
    }

    var body: some View {
        NavigationStack {
            List(shownMatches) { stored in
                NavigationLink {
                    MatchDetailsPlaceholder()
                } label: {
                    MatchRow(stored: stored)
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        matchToDelete = stored
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Matches")
            .searchable(text: $searchText, prompt: "Team or competition")
            .overlay {
                if storedMatches.isEmpty {
                    ContentUnavailableView(
                        "No Matches Yet",
                        systemImage: "sportscourt",
                        description: Text("Matches you track will appear here.")
                    )
                } else if shownMatches.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .confirmationDialog(
                deleteTitle,
                isPresented: Binding(get: { matchToDelete != nil }, set: { if !$0 { matchToDelete = nil } }),
                titleVisibility: .visible,
                presenting: matchToDelete
            ) { stored in
                Button("Delete Match", role: .destructive) { delete(stored) }
            } message: { _ in
                Text("It will be deleted with all its events. This can't be undone.")
            }
            .alert(
                "Couldn't Delete the Match",
                isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private var deleteTitle: String {
        guard let matchToDelete else { return "Delete this match?" }
        return "Delete \(matchToDelete.team1Name) v \(matchToDelete.team2Name)?"
    }

    private func delete(_ stored: StoredMatch) {
        do {
            try MatchList.delete(stored, from: context)
        } catch {
            context.rollback()
            deleteError = error.localizedDescription
        }
        matchToDelete = nil
    }
}

/// Where tapping a match leads until the match details screen is built.
private struct MatchDetailsPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Match Details",
            systemImage: "stopwatch",
            description: Text("Live tracking comes in the next update.")
        )
    }
}

#if DEBUG
#Preview("Matches", traits: .sampleMatches) {
    MatchListView()
}

#Preview("No matches", traits: .emptyStore) {
    MatchListView()
}
#endif
