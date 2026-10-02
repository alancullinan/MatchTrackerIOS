import MatchCore
import SwiftUI

/// Moves the clock of the period being played on or back, e.g. when it was
/// started late. The clock keeps running while it is adjusted; Done applies
/// the change on top of it. Changing period is the main button's job, so
/// period ends are always recorded.
struct ClockEditor: View {
    let session: MatchSession

    @Environment(\.dismiss) private var dismiss
    @State private var offset = 0

    private static let steps = [-60, -10, 10, 60]

    var body: some View {
        let clock = session.match.clock
        NavigationStack {
            VStack(spacing: 20) {
                Text(clock.period.displayName.uppercased())
                    .font(MatchTheme.display(18, .bold))
                    .tracking(2.5)
                    .foregroundStyle(MatchTheme.gold)
                TimelineView(.periodic(from: clock.runningSince ?? .now, by: 1)) { timeline in
                    Text(MatchClock.text(seconds: max(0, clock.elapsed(at: timeline.date) + offset)))
                        .font(MatchTheme.display(72))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                HStack(spacing: 10) {
                    ForEach(Self.steps, id: \.self) { step in
                        Button { offset += step } label: {
                            Text(label(step))
                                .font(MatchTheme.display(20, .bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glass)
                    }
                }
                Text(offsetText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Adjust Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        session.adjustClock(by: offset, at: .now)
                        dismiss()
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: offset)
        .presentationDetents([.medium])
    }

    private func label(_ step: Int) -> String {
        let size = abs(step) >= 60 ? "\(abs(step) / 60) min" : "\(abs(step)) s"
        return (step < 0 ? "−" : "+") + size
    }

    private var offsetText: String {
        guard offset != 0 else { return "The clock keeps running while you adjust it." }
        let size = MatchClock.text(seconds: abs(offset))
        return offset > 0 ? "\(size) added" : "\(size) taken off"
    }
}

#if DEBUG
#Preview("Adjust clock") {
    ClockEditor(session: .preview(.secondHalf))
}
#endif
