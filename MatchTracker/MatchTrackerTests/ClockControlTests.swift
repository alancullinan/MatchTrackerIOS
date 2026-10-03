import Foundation
import MatchCore
import Testing
@testable import MatchTracker

@MainActor
struct ClockControlTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func newMatch() -> Match {
        Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "Cuala", date: t0)
    }

    /// A match taken through `steps` next steps, a minute apart.
    private func match(afterSteps steps: Int) -> Match {
        var match = newMatch()
        for step in 0..<steps { match.takeNextStep(at: at(Double(step) * 60)) }
        return match
    }

    // MARK: What the button shows

    @Test func beforeThrowInAHoldStartsTheFirstHalf() {
        let control = ClockControl(match: newMatch())
        #expect(control.glyph == .play)
        #expect(control.hint == "Hold to start 1st half")
        #expect(control.tapAction == nil)
        #expect(control.holdAction == .nextStep)
        #expect(control.accessibilityLabel == "Start 1st Half")
        #expect(control.defaultAction == .nextStep)
    }

    @Test func whileRunningATapPausesAndAHoldEndsTheHalf() {
        let control = ClockControl(match: match(afterSteps: 1))
        #expect(control.glyph == .pause)
        #expect(control.hint == "Tap to pause · Hold to end 1st half")
        #expect(control.tapAction == .pause)
        #expect(control.holdAction == .nextStep)
        #expect(control.accessibilityLabel == "Pause clock")
        #expect(control.stepName == "End 1st Half")
        #expect(control.defaultAction == .pause)
    }

    @Test func whilePausedATapResumes() {
        var match = match(afterSteps: 1)
        let paused = match.pause(at: at(300))
        #expect(paused)
        let control = ClockControl(match: match)
        #expect(control.glyph == .play)
        #expect(control.hint == "Tap to resume · Hold to end 1st half")
        #expect(control.tapAction == .resume)
        #expect(control.accessibilityLabel == "Resume clock")
    }

    @Test func atHalfTimeAHoldStartsTheSecondHalf() {
        let control = ClockControl(match: match(afterSteps: 2))
        #expect(control.glyph == .play)
        #expect(control.hint == "Hold to start 2nd half")
        #expect(control.tapAction == nil)
        #expect(control.defaultAction == .nextStep)
    }

    @Test func atFullTimeAHoldStartsExtraTime() {
        let control = ClockControl(match: match(afterSteps: 4))
        #expect(control.hint == "Hold to start extra time")
        #expect(control.holdAction == .nextStep)
    }

    @Test func abbreviationsKeepTheirCapitals() {
        let control = ClockControl(match: match(afterSteps: 6))
        #expect(control.hint == "Hold to start ET 2nd half")
    }

    @Test func afterExtraTimeTheButtonDoesNothing() {
        let control = ClockControl(match: match(afterSteps: 8))
        #expect(control.glyph == .done)
        #expect(control.hint == "Full Time (AET)")
        #expect(control.tapAction == nil)
        #expect(control.holdAction == nil)
        #expect(control.defaultAction == nil)
    }

    // MARK: Telling a tap from a hold

    @Test func anEarlyReleaseIsATap() {
        let control = ClockControl(match: match(afterSteps: 1))
        var press = ClockPress()
        press.began()
        #expect(press.isPressed)
        #expect(press.ended(control) == .pause)
        #expect(!press.isPressed)
    }

    @Test func aCompletedHoldTakesTheStepAndNeverAlsoTaps() {
        let control = ClockControl(match: match(afterSteps: 1))
        var press = ClockPress()
        press.began()
        #expect(press.completeHold(control) == .nextStep)
        #expect(press.completeHold(control) == nil)
        #expect(press.ended(control) == nil)
    }

    @Test func aHoldCompletingAfterTheReleaseDoesNothing() {
        let control = ClockControl(match: match(afterSteps: 1))
        var press = ClockPress()
        press.began()
        _ = press.ended(control)
        #expect(press.completeHold(control) == nil)
    }

    @Test func aReleaseWithoutAPressDoesNothing() {
        let control = ClockControl(match: match(afterSteps: 1))
        var press = ClockPress()
        #expect(press.ended(control) == nil)
    }

    @Test func aTapInABreakDoesNothing() {
        let control = ClockControl(match: match(afterSteps: 2))
        var press = ClockPress()
        press.began()
        #expect(press.ended(control) == nil)
    }

    @Test func eachPressStartsAfresh() {
        let control = ClockControl(match: match(afterSteps: 1))
        var press = ClockPress()
        press.began()
        _ = press.completeHold(control)
        _ = press.ended(control)

        press.began()
        #expect(press.ended(control) == .pause)
    }
}
