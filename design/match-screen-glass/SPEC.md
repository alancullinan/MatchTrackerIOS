# Match screen: glass restyle — design handoff

This is the PLAN.md item **"Another pass on the match screen's look, with the owner"**. The owner has signed off a new look, mocked up here:
https://claude.ai/artifact/2QBd8XiVyBibpvRuRhrcRA (private to the owner, board "A").

**It is a restyle of the existing `MatchScreen/` views, plus one behaviour change: the clock button.** Everything else in CLAUDE.md → "Match screen: look and flow" keeps working as it does now: the scorer sheet, More, the event sheets, undo, the events list, the clock editor and team sheets. Where this file and CLAUDE.md disagree, this file wins, and CLAUDE.md and PLAN.md are updated in the same PR (see §8).

`MatchCore` should need **no changes**. Everything below maps onto APIs that already exist (`nextStep`, `takeNextStep(at:)`, `start(at:)`, `pause(at:)`, `lastPeriodEnd`, `score(_:)`, the undo methods). If something seems to need a `MatchCore` change, stop and say why first.

## Files in this folder

| File | What it is |
|---|---|
| `SPEC.md` | This brief. |
| `match-view.html` | The mockup as static HTML/CSS. Use it for exact sizes, colours, radii and spacing. It is a visual reference only: build natively, don't port the CSS. |
| `screenshot-1st-half-running.jpg` | Main state: a half in play, clock running. |
| `screenshot-paused.jpg` | Paused during a half. |
| `screenshot-long-press-in-progress.jpg` | The clock button mid-hold, ring part filled. |
| `screenshot-half-time.jpg` | A break, waiting for the next step. |
| `grass-background.jpg` | The background image (already softened). Add it to the asset catalogue. |
| `grass-background-sharp-source.jpg` | The unblurred source, if the blur is better done in code. |

The screenshots are at 3x (1170 × 2532), designed at 390 × 844 pt.
- Their clock times and scores are **sample data**.
- The scores in them are shown unpadded (`1-2`). The app keeps its existing rule: points padded, `1-02` (see §3).
- The bottom bar in them shows the mockup's placeholder. The real bottom area is the last-event card (§1.6).

---

## 1. Layout, top to bottom

All measurements are in points at a 390 pt width. Keep to safe areas.

### 1.1 Background and appearance
- **The match screen is always dark**, including the sheets it presents. Owner's decision: glass on the grass reads best and the photo is dark-only.
  - Force `.dark` on this screen only. The rest of the app still follows the system setting.
- **Background:** `grass-background.jpg`, filling the screen and ignoring safe areas.
  - Overlay `Color(red: 4/255, green: 24/255, blue: 10/255).opacity(0.30)` on top.
  - It replaces `PitchBackground`'s stripes on the match screen.
  - Don't blur it further.
- **Reduce Transparency:** drop the photo for a solid `#10301C`, and make the glass panels solid.

### 1.2 Top bar
- **Left:** Back, a circular glass button, 44 pt.
- **Right:** **the current actions, unchanged**, in one glass capsule:
  - Events list
  - Stats
  - The ••• menu (share, live link, edit match, team colours, scorer settings, match note, adjust clock)
- The mockup's four icons were placeholders. Keep today's set. The owner chose this.
- Prefer the system toolbar if on iOS 26 it gives one grouped glass capsule; otherwise build one with `GlassEffectContainer`.

### 1.3 Competition name
- Small and centred: 15 pt semibold, white at 85%.
- No team names here.

### 1.4 Clock capsule
- One centred glass capsule, about 88 pt tall and fully rounded. Padding: 26 pt leading, 6 pt elsewhere.
- **Left side:**
  - Period label: 11 pt bold, tracking +0.1em, yellow `#FFD60A`. Uppercased `displayName`, plus ` · PAUSED` while paused in a playing period.
  - Clock: 52 pt semibold, standard SF Pro with **monospaced digits**.
  - Keep the existing rule: during a break it shows how long the last half ran (from `lastPeriodEnd`), never 00:00. Keep the existing `ClockView` text logic; only the styling changes.
- **Tapping the clock text** still opens the clock editor (existing behaviour).
- **Right side:** the clock button (§2):
  - A 62 pt `#FFD60A` circle with a dark glyph (`#1A1A00`).
  - Inside a 76 pt progress ring: 4 pt stroke, track white 18%, fill white, starting at 12 o'clock.
- **Hint line** under the capsule: 12 pt medium, white 75%. Its text comes from the state (§2).

### 1.5 Team cards (two, stacked, 14 pt gap)
- **Card:** a glass rounded rectangle, radius 32, padding 14.
  - **No colour tint.** The owner chose plain glass with a badge (below).
- **Row 1:**
  - **Leading:** the team's **colour badge**, the existing one from `TeamColorViews`. It goes in the empty top-left corner the mockup leaves, level with the name.
  - **Centre:** team name, 20 pt bold.
  - **Trailing:** the **total points pill**, e.g. `32 pts`. 17 pt bold, monospaced digits, on a `black.opacity(0.28)` capsule with 4 × 12 padding.
  - The total moves here from under the score.
- **Row 2:** the score, centred.
  - 64 pt bold, standard SF Pro, monospaced digits, tracking −0.03em.
  - The separator is a short yellow hyphen with 3 pt either side.
  - The score text follows the existing rule: points padded, `1-05`.
- **Flag buttons:**
  - 62 pt circles, **vertically centred on the whole card** (not on the score row), inset 16 pt from the edges.
  - **Goal (leading):** fill `#30D158` at 22%, 1 pt border at 60%, green flag.
  - **Point (trailing):** fill white 18%, border white 55%, white flag.
  - The glyph is a waving flag on a pole, about 36 pt (the SVG is in `match-view.html`), drawn as a SwiftUI `Shape`.
  - No text labels. Keep the VoiceOver labels.
  - **When the ball isn't in play**, keep the existing rule (flags disabled) and show them at 40% opacity.
- **Row 3:** "+ More", centred. A glass capsule, 36 pt tall, `plus` + "More" at 15 pt semibold. It opens the existing More sheet.
- **Long scores must fit** between the flags: `.lineLimit(1)` and `.minimumScaleFactor(0.7)`. Test with `12-21`, `3-25` and `1-05`.

### 1.6 Bottom: the last-event card
The mockup's bottom bar is replaced by the **existing last-event card**, restyled to match it:
- A glass panel 8 pt in from the screen edges, radius 38, with the mockup's padding.
- Content and behaviour as now: the last event with **Undo** and **Details** for 6 seconds after each change, including period starts and ends.
- When nothing recent is showing, keep today's idle content, restyled. Don't add a swipe-up match log: the events list stays in the toolbar (see CLAUDE.md for why).

---

## 2. The clock button: one button for the clock and the main step

This replaces the big bottom "next step" button and the pause/resume button beside it.

| Gesture | What it does | `Match` API |
|---|---|---|
| **Tap** | Pause or resume the clock. Only in a playing period; elsewhere it does nothing. | `pause(at:)` / `start(at:)` |
| **Hold ~0.7 s** | Take the next step: start or end a period, extra time included. | `takeNextStep(at:)` |

### What the button shows

| State | Glyph | Hint |
|---|---|---|
| Playing, running | pause | `Tap to pause · Hold to <step title>` |
| Playing, paused | play | `Tap to resume · Hold to <step title>` |
| Break (`nextStep` is `.start`) | play | `Hold to <step title>` |
| Over (`nextStep == nil`, after extra time) | checkmark; hold disabled | `Full Time (AET)` |

The step title comes from `MatchStep.title`, in sentence case in the hint. For example: "Hold to end 1st half", "Hold to start 2nd half", "Hold to start extra time".

At Full Time the hold starts extra time, because there is no finish step (CLAUDE.md → Periods). The hint says so, and a mistaken hold is undone from the last-event card as today.

### The hold must feel deliberate
- While held, the ring fills clockwise over the hold duration, linearly, and the button scales to 0.92.
- Released early, the ring snaps back (about 150 ms ease-out) and the press counts as a **tap**.
- When the hold completes:
  - Give a strong haptic, e.g. `.sensoryFeedback(.success, trigger:)`.
  - Take the step.
  - Reset the ring.
  - Show the step on the last-event card with Undo.
  - **Never also fire the tap.**
- Suggested approach: `onLongPressGesture(minimumDuration: 0.7, perform:onPressingChanged:)` driving a `Circle().trim(from: 0, to: progress)`. The tap is handled separately. Put the press/tap/step decision in a small testable type beside the view, as with `MatchList`, rather than inside the view.

### Accessibility
- The button's label is the tap action ("Pause clock" / "Resume clock").
- Add a named accessibility action for the step ("End 1st Half", from `MatchStep.title`). VoiceOver users can't easily do a timed hold.
- In a break, the step is the button's default action.

---

## 3. Unchanged rules to keep
- Scoring, the scorer sheet, More, misses, fouls, kickouts, subs, notes, the team sheet, the events list, time editing: all as now.
- Score text (`Score`, points padded), two-pointer totals, stats.
- The wall-clock timer. Never a tick counter.
- Haptics on scores as now.

## 4. Visual tokens (dark only)

| Token | Value |
|---|---|
| Gold / accent | `#FFD60A`. Update `MatchTheme.gold`, which is now dark-only on this screen. |
| Gold ink (glyph on the gold button) | `#1A1A00` |
| Goal green | `#30D158` |
| Text | white; secondary white 70–85% |
| Glass | System Liquid Glass (`.glassEffect` / glass button styles), grouped in `GlassEffectContainer`s. Check the API names against the Xcode 27 SDK. Don't fake it with materials. |
| Type | Standard SF Pro everywhere. The owner chose it over the condensed scoreboard lettering, so retire or update `MatchTheme.display`. Monospaced digits for every changing number. |
| Radii | Cards 32, bottom panel 38, capsules fully rounded |
| Hit targets | 44 pt minimum |

## 5. Previews and checks
- Update the match screen previews to show each clock state:
  - Pre-match
  - Running
  - Paused
  - Half time
  - Full time
  - After extra time
  - A long hurling score (`12-21`)
- Add samples to `SampleMatches` where a state is missing.
- Check in the Simulator with `-sampleStore` against the screenshots, including on a small iPhone. The second card's More button must not be covered by the last-event card (CLAUDE.md lesson).
- Test the hold/tap decision type. `swift test` for `MatchCore` should be untouched and still pass.

## 6. Out of scope
- Live Activity
- Scorer sheet and event sheet visuals: they inherit dark mode; restyle them later.

## 7. Suggested PR split
1. Background, forced dark, the glass top bar and the clock capsule. The clock button keeps today's behaviour for now.
2. The clock button's tap and hold, with the ring, haptics and accessibility, replacing the bottom step and pause buttons.
3. Team cards (badge, total pill, centred flags, More) and the restyled last-event card.

## 8. Docs to update in the same PRs
- **CLAUDE.md → "Match screen: look and flow":**
  - Swap the mockup link for the one at the top of this file.
  - Rewrite **Look**: grass photo, always dark, plain glass cards with a colour badge, SF Pro, the yellow accent.
  - Rewrite **Layout** to match §1 and §2: one clock button (tap to pause, hold for the next step) in place of the bottom big button and pause button.
- **PLAN.md:**
  - Tick "Another pass on the match screen's look".
  - Add a Decisions row: "Main button: tap pauses/resumes, hold (~0.7 s, with a fill ring and haptic) takes the next step. One control instead of two, and the hold makes accidental period changes rare; Undo still covers them."
