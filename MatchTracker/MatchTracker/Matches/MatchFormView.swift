import MatchCore
import SwiftData
import SwiftUI

/// Creates a match, or edits the details of one: teams, code, competition,
/// date, venue and referee. Players, events and the clock are not touched.
struct MatchFormView: View {
    /// The match being edited; `nil` to create one.
    let editing: Match?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// The code chosen for the last new match, offered first next time.
    @AppStorage("lastMatchType") private var lastMatchType = MatchType.football

    @State private var details: MatchDetails
    @State private var saveError: String?
    @FocusState private var focusedField: Field?

    private enum Field { case team1, team2, competition, venue, referee }

    init(editing: Match? = nil) {
        self.editing = editing
        // Replaced by the last-used code in `onAppear` for a new match.
        _details = State(initialValue: editing?.details ?? MatchForm.newDetails(matchType: .football, now: .now))
    }

    private var isNew: Bool { editing == nil }
    private var canChangeCode: Bool { editing?.canChangeMatchType ?? true }

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    TextField("Team 1", text: $details.team1Name)
                        .focused($focusedField, equals: .team1)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .team2 }
                    TextField("Team 2", text: $details.team2Name)
                        .focused($focusedField, equals: .team2)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .competition }
                }
                .textInputAutocapitalization(.words)

                Section {
                    Picker("Code", selection: $details.matchType) {
                        ForEach(MatchType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .disabled(!canChangeCode)
                    TextField("Competition", text: $details.competition)
                        .focused($focusedField, equals: .competition)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .venue }
                        .textInputAutocapitalization(.words)
                    DatePicker("Throw-in", selection: $details.date)
                } header: {
                    Text("Match")
                } footer: {
                    if !canChangeCode {
                        Text("The code can't be changed once the match has started.")
                    }
                }

                Section("Optional") {
                    TextField("Venue", text: $details.venue)
                        .focused($focusedField, equals: .venue)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .referee }
                    TextField("Referee", text: $details.referee)
                        .focused($focusedField, equals: .referee)
                        .submitLabel(.done)
                }
                .textInputAutocapitalization(.words)
            }
            .navigationTitle(isNew ? "New Match" : "Edit Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save", role: .confirm, action: save)
                        .disabled(!details.isComplete)
                }
            }
            // Don't lose typing to an accidental swipe; Cancel still closes it.
            .interactiveDismissDisabled(hasChanges)
            .alert(
                "Couldn't Save the Match",
                isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(saveError ?? "")
            }
            .onAppear {
                if isNew {
                    details.matchType = lastMatchType
                    focusedField = .team1
                }
            }
        }
    }

    private var hasChanges: Bool {
        if let editing { return details != editing.details }
        let typed = details.trimmed
        return [typed.team1Name, typed.team2Name, typed.competition, typed.venue, typed.referee]
            .contains { !$0.isEmpty }
    }

    private func save() {
        do {
            guard try MatchForm.save(details, editing: editing?.id, in: context) != nil else { return }
            if isNew { lastMatchType = details.matchType }
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview("New match", traits: .emptyStore) {
    MatchFormView()
}

#Preview("Editing a started match", traits: .emptyStore) {
    var match = Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "St. Vincent's",
                          competition: "Senior Football League", date: .now, venue: "Mobhi Road")
    match.start(at: .now)
    return MatchFormView(editing: match)
}
#endif
