import MatchCore
import SwiftUI

/// What the clock button shows and does in a match's current state: a tap
/// pauses or resumes play; a hold takes the next step (start or end a period).
struct ClockControl: Equatable {
    enum Glyph: Equatable {
        case pause, play, done

        var systemImage: String {
            switch self {
            case .pause: "pause.fill"
            case .play: "play.fill"
            case .done: "checkmark"
            }
        }
    }

    let glyph: Glyph
    /// The line under the clock capsule, e.g. "Tap to pause · Hold to end 1st half".
    let hint: String
    /// What a tap does: pause or resume, only in a playing period.
    let tapAction: MatchSession.Action?
    /// What a completed hold does: the next step, or `nil` once the match is over.
    let holdAction: MatchSession.Action?
    /// The button's VoiceOver label: the tap action, or the step when there is none.
    let accessibilityLabel: String
    /// The step as a named VoiceOver action ("End 1st Half"), since a timed
    /// hold is hard with VoiceOver.
    let stepName: String?

    /// What VoiceOver's default action does: the tap, or the step in a break.
    var defaultAction: MatchSession.Action? { tapAction ?? holdAction }

    init(match: Match) {
        let period = match.clock.period
        let step = match.nextStep
        holdAction = step == nil ? nil : .nextStep
        stepName = step?.title
        let hold = step.map { "Hold to \(Self.sentenceCase($0.title))" }

        if period.isPlaying {
            let running = match.clock.isRunning
            glyph = running ? .pause : .play
            tapAction = running ? .pause : .resume
            accessibilityLabel = running ? "Pause clock" : "Resume clock"
            hint = [running ? "Tap to pause" : "Tap to resume", hold].compactMap(\.self).joined(separator: " · ")
        } else if let step, let hold {
            glyph = .play
            tapAction = nil
            accessibilityLabel = step.title
            hint = hold
        } else {
            glyph = .done
            tapAction = nil
            accessibilityLabel = period.displayName
            hint = period.displayName
        }
    }

    /// "End 1st Half" as "end 1st half"; abbreviations such as "ET" stay as they are.
    static func sentenceCase(_ title: String) -> String {
        title.split(separator: " ").map { word in
            word.count > 1 && word.allSatisfy(\.isUppercase) ? String(word) : word.lowercased()
        }.joined(separator: " ")
    }
}

/// One press of the clock button, deciding between a tap and a hold. A press
/// released before the hold completes is a tap; once the hold has completed,
/// the release does nothing, so a hold never also pauses or resumes.
struct ClockPress {
    private(set) var isPressed = false
    private var holdCompleted = false

    mutating func began() {
        isPressed = true
        holdCompleted = false
    }

    /// The hold time has passed with the button still down: returns the step to take.
    mutating func completeHold(_ control: ClockControl) -> MatchSession.Action? {
        guard isPressed, !holdCompleted else { return nil }
        holdCompleted = true
        return control.holdAction
    }

    /// The finger lifted: returns the tap's action if the hold didn't complete.
    mutating func ended(_ control: ClockControl) -> MatchSession.Action? {
        guard isPressed else { return nil }
        isPressed = false
        return holdCompleted ? nil : control.tapAction
    }
}

/// The yellow clock button: tap to pause or resume, hold to take the next
/// step. While held, the ring fills over the hold time.
struct ClockButton: View {
    let control: ClockControl
    let perform: (MatchSession.Action) -> Void

    /// How long a press must be held to take the next step, in seconds.
    static let holdSeconds = 0.7

    @State private var press = ClockPress()
    @State private var progress = 0.0
    @State private var hold: Task<Void, Never>?
    @State private var completedHolds = 0

    var body: some View {
        ClockButtonFace(systemImage: control.glyph.systemImage, progress: progress, isPressed: press.isPressed)
            .animation(.easeOut(duration: 0.15), value: press.isPressed)
            .contentShape(.circle)
            // The hold is timed here rather than by the gesture, so a release
            // is always reported after a completed hold, never before it.
            .onLongPressGesture(minimumDuration: 3600, maximumDistance: 30, perform: {}) { pressing in
                pressing ? began() : ended()
            }
            .sensoryFeedback(.success, trigger: completedHolds)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(control.accessibilityLabel)
            .accessibilityAction {
                if let action = control.defaultAction { perform(action) }
            }
            .accessibilityActions {
                if let stepName = control.stepName, control.tapAction != nil {
                    Button(stepName) { perform(.nextStep) }
                }
            }
    }

    private func began() {
        press.began()
        guard control.holdAction != nil else { return }
        withAnimation(.linear(duration: Self.holdSeconds)) { progress = 1 }
        hold = Task {
            try? await Task.sleep(for: .seconds(Self.holdSeconds))
            guard !Task.isCancelled, let action = press.completeHold(control) else { return }
            completedHolds += 1
            perform(action)
            withAnimation(.easeOut(duration: 0.15)) { progress = 0 }
        }
    }

    private func ended() {
        hold?.cancel()
        hold = nil
        if let action = press.ended(control) { perform(action) }
        withAnimation(.easeOut(duration: 0.15)) { progress = 0 }
    }
}

#if DEBUG
#Preview("Clock button faces") {
    HStack(spacing: 16) {
        ClockButtonFace(systemImage: "pause.fill")
        ClockButtonFace(systemImage: "pause.fill", progress: 0.6, isPressed: true)
        ClockButtonFace(systemImage: "play.fill")
        ClockButtonFace(systemImage: "checkmark")
    }
    .padding()
    .background { GrassBackground() }
}
#endif
