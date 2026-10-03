import MatchCore
import SwiftData
import SwiftUI

/// A panel's name and its names by jersey number: the starting 15, then the
/// subs, with players 31 to 40 added on demand. Nothing is saved until Done.
struct PanelEditor: View {
    /// The panel being edited, or `nil` for a new one.
    let panel: PlayerPanel?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var slots: [PanelSlot] = []
    @State private var loaded = false
    @State private var saveError: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable { case name, slot(Int) }

    private var original: PlayerPanel { panel ?? .empty(name: "") }
    private var hasChanges: Bool { loaded && (name != original.name || slots != original.slots) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Panel name, e.g. Senior Hurlers", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .slot(1) }
                }
                Section("Starting 15") {
                    ForEach($slots.filter { $0.wrappedValue.jerseyNumber <= 15 }, id: \.wrappedValue.jerseyNumber) { $slot in
                        row($slot)
                    }
                }
                Section {
                    ForEach($slots.filter { $0.wrappedValue.jerseyNumber > 15 }, id: \.wrappedValue.jerseyNumber) { $slot in
                        row($slot)
                            .deleteDisabled(!canRemove(slot))
                    }
                    .onDelete { _ in removeLast() }
                    if let next = nextSlot {
                        Button("Add Player \(next.jerseyNumber)", systemImage: "plus.circle.fill") {
                            slots.append(next)
                            focused = .slot(next.jerseyNumber)
                        }
                    }
                } header: {
                    Text("Subs")
                } footer: {
                    Text("Up to \(PlayerPanel.maxSize) players. An added player can be removed by swiping.")
                }
            }
            .navigationTitle(panel == nil ? "New Panel" : "Edit Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm, action: save)
                        .disabled(!canSave)
                }
            }
            .alert(
                "Couldn't Save the Panel",
                isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(saveError ?? "")
            }
        }
        // A swipe down mustn't lose names being typed; Cancel or Done closes it.
        .interactiveDismissDisabled(hasChanges)
        .onAppear {
            guard !loaded else { return }
            name = original.name
            slots = original.slots
            loaded = true
            if panel == nil { focused = .name }
        }
    }

    private func row(_ slot: Binding<PanelSlot>) -> some View {
        let number = slot.wrappedValue.jerseyNumber
        return HStack(spacing: 12) {
            Text("\(number)")
                .font(MatchTheme.display(22, .bold))
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
            TextField("Name", text: Binding(
                get: { slot.wrappedValue.name ?? "" },
                set: { slot.wrappedValue.name = $0 }
            ))
            .textContentType(.name)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .focused($focused, equals: .slot(number))
            .onSubmit { focused = number < slots.count ? .slot(number + 1) : nil }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(number)")
    }

    private var nextSlot: PanelSlot? {
        slots.count < PlayerPanel.maxSize ? PanelSlot(jerseyNumber: slots.count + 1) : nil
    }

    /// Only the last slot, and only an added one, so numbers stay in order.
    private func canRemove(_ slot: PanelSlot) -> Bool {
        slot.jerseyNumber == slots.count && slot.jerseyNumber > PlayerPanel.startingSize
    }

    private func removeLast() {
        guard let last = slots.last, canRemove(last) else { return }
        slots.removeLast()
    }

    private func save() {
        var edited = panel ?? .empty(name: "", createdAt: .now)
        guard edited.update(name: name, slots: slots) else { return }
        do {
            try PanelList.save(edited, in: context)
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview("New panel", traits: .emptyStore) {
    PanelEditor(panel: nil)
}

#Preview("Edit panel", traits: .emptyStore) {
    PanelEditor(panel: SampleMatches.panel)
}
#endif
