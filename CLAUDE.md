# CLAUDE.md

Guidance for Claude (Claude in Xcode and Claude Code) working in this repository.

## Project

MatchTracker for iOS: a native SwiftUI app for tracking Gaelic games matches (Football, Hurling, Ladies Football, Camogie) live from the sideline - timer, scoring, events, players, stats and sharing.

It succeeds an unreleased PWA ([`alancullinan/matchtrackerpwa`](https://github.com/alancullinan/matchtrackerpwa)), used only by the owner. **The PWA is a reference, not a constraint:** read its `script.js` to see how a feature or a rule of the sport was handled, then design the best iOS version. Never shape the app, its model or its tests to stay compatible with the PWA.

Other MatchTracker repos exist (`MatchTracker`, the original 2025 Swift app, and `MatchTrackerV2`, an earlier rebuild). **Do not use them as a reference or copy from them.**

`PLAN.md` holds the phased plan and checklists. Tick items off there as work lands.

## How we work

- Most coding happens in **Claude Code in Terminal** on the Mac, run from the repo root. Xcode is for Previews, the Simulator, device runs and signing.
- **GitHub is the shared space.** Everything lives in this repo - code, `CLAUDE.md`, `PLAN.md` - so any Claude Code session can read it, review PRs and discuss.
- Work on a branch and open a PR; keep PRs to one checklist item or a small group of them. PRs are squash-merged.
- Run `swift test` (and build the app, where Xcode is available) before pushing. A PR description says which tests ran and where; if something couldn't be run, it says so.
- Tick the item in `PLAN.md` in the same PR, and record any decision or deviation in `CLAUDE.md` or `PLAN.md`.
- Never include an AI model name in commits, PRs or code comments.

### Building and checking the app (on the Mac)
- **Build and test the app yourself; never ask the owner to paste build output, errors or logs.** Read them directly.
- With Xcode's MCP server connected (`/mcp` lists `xcode`), use its tools to build, run tests, render Previews and drive the Simulator.
- Otherwise use the command line. Find an installed simulator with `xcrun simctl list devices available iPhone` (don't assume a model exists), then:
  `xcodebuild test -project MatchTracker/MatchTracker.xcodeproj -scheme MatchTracker -destination 'platform=iOS Simulator,name=<that iPhone>'`
- Loop until it builds and the tests pass, then check UI changes in Previews or the Simulator before opening a PR.
- **Previews:** render one at a time (parallel renders fail). If a render fails with "Library not loaded: /usr/lib/libSystem.B.dylib", the Preview simulator is wedged, not the code: run `xcrun simctl --set previews shutdown all` and render again. In a Preview, don't create an object (e.g. a `MatchSession`) in `onAppear`; it crashed the Preview runtime. Build it with a static `preview(...)` helper instead.

### One-off setup on the Mac
- **Point the command line at Xcode 27**: `sudo xcode-select -s /Applications/Xcode.app` (check with `xcode-select -p`). Otherwise Terminal's `swift` is the Command Line Tools' older Swift, and `swift test` fails with "no such module 'Testing'". Other Xcode copies on the Mac (e.g. `Xcode New.app`, Swift 6.2) are not the project's toolchain.
- **Xcode's MCP server**, so Claude Code can build, run tests, render Previews and use the Simulator itself: in Xcode open Settings → Intelligence and turn on **Xcode Tools**; then, in Terminal, `claude mcp add --transport stdio xcode -- xcrun mcpbridge` (check with `claude mcp list`). Xcode must be running with the project open. With it, check UI work in Previews or the Simulator before opening a PR.
- **SwiftUI Pro skill** (optional, recommended): Paul Hudson's agent skill for current SwiftUI APIs, navigation, state and accessibility. In Claude Code: `/plugin marketplace add twostraws/SwiftUI-Agent-Skill`, then `/plugin install swiftui-pro@swiftui-agent-skill`.

## Architecture

```
MatchTracker/                   Xcode project folder
  MatchTracker.xcodeproj        open this in Xcode
  MatchTracker/                 iOS app target sources (SwiftUI, SwiftData)
    Storage/                    SwiftData records (StoredMatch, StoredPanel) and the store
    Matches/                    the match list (the home screen), its rows, and sample matches for Previews
    MatchScreen/                the match screen: `MatchSession` (applies, saves and undoes changes), theme, parts, `ScorerSheet`, `EventSheets` (foul, kickout, substitution and note sheets, and their shared parts), `EventText`
    Teams/                      team colour badge and picker (`KitColor.color` lives here, not in MatchCore)
  MatchTrackerTests/            app tests (Swift Testing), run by CI
MatchCore/                      local Swift package - the domain layer (linked as ../MatchCore)
  Package.swift
  Sources/MatchCore/
    Model/                      the app's own native model and logic
    PWA/                        one-off importer for the owner's PWA backup (isolated; see below)
  Tests/MatchCoreTests/
    Fixtures/                   the owner's PWA backup, anonymised - used only by importer tests
README.md                       short overview for the GitHub page
CLAUDE.md, PLAN.md              repo root - Claude in Xcode does not show these in the project
                                navigator; read them from here at the start of each task
```

The repo must not live in an iCloud-synced folder (Desktop, Documents, iCloud Drive): git commits fail with "Resource deadlock avoided" and the repo can be corrupted. Keep it in e.g. `~/Developer/MatchTrackerIOS`.

### MatchCore at a glance

| File (`Sources/MatchCore/Model/`) | What it holds |
| --- | --- |
| `Match.swift` | `Match` (teams, events, clock, `legacyID`, `liveShareID`), `Match.new(...)`, `match[.team1]` |
| `MatchDetails.swift` | `MatchDetails` (what the match form edits), `Match.new(details)`, `match.apply(_:)`, `canChangeMatchType`, `MatchType.displayName` |
| `Team.swift`, `Player.swift`, `TeamSide.swift` | 30-player rosters (`Team.roster`), optional names, `Team.colors`, `Team.asksForScorers`, `.team1` / `.team2` |
| `TeamColors.swift` | `KitColor` (the palette, stored by case name) and `TeamColors` (main + optional second colour) |
| `MatchEvent.swift` | `MatchEvent` and its `Kind` (shot, foul, card, kickout, substitution, note, periodEnd); `side` and `type` |
| `MatchClock.swift` | Wall-clock timer: `elapsed(at:)`, `start(at:)`, `pause(at:)` |
| `MatchPeriods.swift` | `isPlaying`, `displayName`, `match.start/pause/endPeriod(at:)`, `match.record(_:note:at:)`, `canRecordEvents`, `nextPlayingPeriod` |
| `MatchSteps.swift` | `MatchStep` and `nextStep` / `takeNextStep(at:)` (the main button), `undoLastEvent()`, `undoPeriodStart()`, `lastPeriodEnd`, `MatchClock.text(seconds:)`, `MatchEvent.minute` |
| `ShotDetails.swift` | `ShotOutcome.alternatives(in:)`, `ShotType.options(for:)` (45 or 65), `match.updateShot(...)`, `match.deleteEvent(_:)`, `match.event(_:)` |
| `EventDetails.swift` | `match.updateFoul/updateKickout/updateSubstitution/updateNote(...)`, `CardType.offered`, `CardType`/`FoulOutcome.displayName` |
| `EventOrder.swift` | `eventsInOrder`, `eventsNewestFirst`, `score(_:through:)` (score at any event) |
| `Score.swift` | `Score` (goals, points, two-pointers, total, "1-05"), `match.score(_:)`, `MatchType.allowsTwoPointers` |
| `Stats.swift` | `match.stats(_:)` → `TeamStats`: shooting, per-player stats with score by shot type, fouls, cards, substitutions |
| `PlayerPanel.swift` | 30-slot panels (`PlayerPanel.empty`) |
| `Identifiers.swift`, `Enums.swift` | Typed UUID ids; the enums |

### MatchCore rules
- **Foundation only.** Never import SwiftUI, SwiftData, UIKit or any Apple-platform-only framework. It must build and test with `swift test` on macOS *and* Linux, so Claude Code cloud sessions can run its tests.
- Plain `Codable`, `Sendable`, value-type models. The app target maps them to SwiftData; nothing in `MatchCore` knows about storage.
- **The native model is designed for Swift.** Make invalid states unrepresentable:
  - `MatchEvent` holds the shared fields (id, period, time, note) plus a `kind` enum with one case per event type, each carrying only its own data (a shot has an outcome and shot type; a card has a card type). No bag of optional fields.
  - IDs are random `UUID`s, wrapped in small typed IDs. Imported records also keep their PWA id as `legacyID`, only so the import can skip a match it has already brought in.
  - Teams are referenced by side (`.team1` / `.team2`), not by a team-id string.
  - An unnamed player has `name == nil`; never a `No.N` placeholder.
  - A period-end event records the period that **ended** (e.g. `.firstHalf`).
  - The clock is `period` + seconds banked + `runningSince: Date?`, so running time is always derived from the wall clock.
  - `note` is a shared optional field on every event, not only `.note` events: shots and substitutions can carry notes too.
  - `.card` exists for older standalone card events; new cards are recorded on a `.foul`.
  - The last panel imported into a team is `Team.lastPanelID`.
  - Starting a running clock or pausing a paused one changes nothing, so a double-tap or a repeated pause can never add time twice.
- **Enums are stored by case name** (`firstHalf`, `fullTimeAfterExtraTime`, `foul`). Once matches are saved a case name is permanent: add cases, never rename them. Text shown to people comes from `displayName`.
- **All match logic lives here**, not in views: scoring, period transitions, event sorting, stats. Views call it; they do not re-implement it.
- **Time is passed in**, never read inside `MatchCore`: anything time-dependent takes `at now: Date`. The app passes `Date()`; tests pass fixed dates. Never call `Date()` in `MatchCore`.
- **State changes are safe to repeat.** Methods that change a match return `Bool` (or an optional) and do nothing when they don't apply, so the UI can call them from any button without checking first.
- Every logic change comes with a test.

### Tests
- Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), one file per area (`ScoreTests.swift`, `StatsTests.swift`, ...). Test names read as sentences: `pausingAPausedClockChangesNothing`.
- `#expect` cannot call a `mutating` method; store the result first (`let started = match.start(at: t)` then `#expect(started)`).
- Use whole-second fixed dates so values survive JSON exactly.
- `loadFixture("pwa-backup")` loads the PWA fixture; only importer tests use it.

### App rules
- iOS 26+, iPhone and iPad only: the app target supports no native macOS or visionOS (Xcode's multiplatform template added them; iOS-only APIs such as `textInputAutocapitalization` wouldn't build there). SwiftUI, `NavigationStack`, `@Observable`. No `#available` checks below iOS 26; seed Previews with preview traits (`PreviewModifier` with an in-memory container) and varied sample data.
- **One persistent store: SwiftData, synced to the user's private iCloud database (CloudKit).** iCloud sync is part of that store, not a second one. Never add another store, cache or mirror of match data - a second store that falls out of step silently loses recent matches (it happened in the PWA).
- **SwiftData models must stay CloudKit-compatible**, or sync silently stops working:
  - every stored property is optional or has a default value;
  - no `@Attribute(.unique)` - uniqueness is enforced in code;
  - every relationship is optional, and no `.deny` delete rules;
  - schema changes are additive only (add properties; never rename or remove one once shipped).
- Each user's data lives in their own iCloud account; there is no shared server. Live score sharing, if added, sends only a snapshot of the score, never the match data.
- **Storage (`MatchTracker/Storage/`)**: `StoredMatch` and `StoredPanel` are only how MatchCore values are saved; views and logic work with `Match` and `PlayerPanel`. Write with `context.store(match)` (updates the record with that id, or inserts one - ids are kept unique here, not by the schema) and read with `stored.match()`. Scalar fields are columns; rosters, events and panel slots are encoded with `StoredCoding` (JSON, sorted keys). This is a deliberate exception to Apple's guidance to store your own types as models rather than encoded blobs: nothing ever queries inside events or rosters, and the list filters on columns. It makes the `Codable` shape of `Player`, `MatchEvent` (including `Kind`'s case and label names) and `PanelSlot` a stored format: change it only additively, like the enums. Reading never guesses: an unknown case name or unreadable JSON throws `StoredDataError`, and nothing is overwritten with a default.
- **App structure:** the match list is the home screen (no separate hub); other areas (panels, export) are reached from its toolbar. Screens live in folders by feature (`Matches/`, later `Players/`, `Panels/`). Rules a screen depends on (search, sort, delete) go in a small testable type beside it (e.g. `MatchList`), not in the view.
- **Previews:** use the `.sampleMatches` and `.emptyStore` preview traits (`Matches/SampleMatches.swift`, debug only). When a screen gains a new state, add a sample that shows it.
- Keep a match **self-contained** (its teams, players and events belong to it) so a single match can be shared later. How is undecided - see `PLAN.md`.
- Never delete data that has not been verified - e.g. a migration writes, reads back and compares before removing anything.

## PWA import (low priority, isolated)

The importer in `Sources/MatchCore/PWA/` exists only to bring the owner's own PWA matches across once; it may never be used. It must not influence anything else:
- Nothing outside `PWA/` uses PWA types. The PWA's enums and strings live there as their own types (`PWAPeriod`, `PWAEventType`, ...), so native names can change freely.
- When the native model changes, the importer adapts - or drops what no longer fits - never the other way round.
- The fixture is for importer tests only. Native behaviour is tested on its own terms, never by comparison with the PWA.
- How the PWA's backup format is converted is documented in comments in `PWA/`, not here.

## Rules of the game and lessons learned

Rules of the sport and lessons from real bugs - keep them whatever the UI looks like.

**Match logic**
- Scoring: goal = 3, point = 1, two-pointer = 2. Two-pointers exist for Football and Ladies Football, not Hurling or Camogie (confirmed by the owner). A score shows as goals-points with the points padded ("1-05"); a two-pointer adds 2 to the points.
- Events can be recorded only in playing periods: 1st Half, 2nd Half, Extra Time 1st Half, Extra Time 2nd Half.
- Ending a playing period automatically records a period-end event with the period that ended and its time. The score at that point is derived from the earlier events, never stored, so it stays correct after edits.
- Events sort by period order, then time; newest first in the event list, oldest first for exports and sharing. A period end is always last in its period, even if an edited event's time is later. Events at the same moment keep recorded order. Sorting is computed (`Match.eventsInOrder`), so it stays correct after time or period edits.
- Periods (`MatchPeriods.swift`): `start` begins the next playing period from a break at 0:00, or resumes a paused one; `endPeriod` records the period end and moves to the following break. Periods have no set length: the clock runs until the period is ended, and any match can go to extra time. Each returns `false` and changes nothing when it doesn't apply.
- **There is no step to finish a match.** After the 2nd Half the match is at Full Time, which is the end of it unless extra time is started from there. After Extra Time 2nd Half it moves to `.fullTimeAfterExtraTime`, shown as "Full Time (AET)".
- The timer is **wall-clock based**: running time = banked seconds + (now − `runningSince`), never a tick counter. This is what lets a Live Activity show a clock without the app running.

- Stats: accuracy is scored shots / all shots, and is `nil` (not 0%) with no shots. Players are ranked by score, then jersey number; shots without a player are grouped last. Stats work on any set of events, so a single period can be shown.

**Players and panels**
- Each team has 30 players, jersey numbers 1-30; names are optional.
- A panel has **exactly 30 fixed slots**; the slot is the jersey number. Empty slots are kept; panels are never sorted or compacted.
- Panel import into a team is allowed only before throw-in, overwrites names in place and **never regenerates player ids** (events reference them).

**Data safety**
- iCloud sync is not a backup: deleting a match on one device deletes it everywhere. Deleting a match always needs a confirmation.
- If an export to Files is added later, only a **completed** export counts as a backup (a cancelled share sheet records nothing), and it shares the file only - no title or text - so "Save to Files" saves exactly one file.

## Design principles (UI)

The app is used one-handed, on a sideline, often in rain or sun, while watching the game. Design for that:

- **Fewest taps per event.** The most common actions (score, wide, card, substitution) are reachable from the match screen.
- **Undo, not confirmations.** Record immediately and offer undo ("Point - No.11 · Undo") instead of confirm dialogs. Keep confirmations only for destructive, hard-to-undo actions (deleting a match).
- **Big targets, high contrast**, readable in sunlight; nothing important behind a small icon.
- **Native iOS patterns**: sheets, swipe actions, context menus, haptics, Live Activity - not web-style modals with Cancel/Done bars everywhere.
- The PWA shows which **tasks** matter (record a score, make a substitution, end a period); its layouts are not a template.

### Match screen: look and flow (agreed with the owner)

The agreed design, tried as a clickable mockup: https://claude.ai/artifact/VpABcEtAGK356oxp7Qbx3R (private to the owner). Build the real screen to this; the reasons are in `PLAN.md` → Decisions.

**Look**
- A calm pitch-green background (faint mowing stripes, no photo); cards and the top bar in iOS glass. Light and dark modes both readable in sunlight.
- Gold for the period name and the main button; narrow, condensed scoreboard lettering for the clock and scores.
- Each team has its own colours (chosen per team when creating the match); its card is tinted with them and shows a small colour badge by the name.

**Layout, top to bottom**
- Top bar: Back on the left; Stats and a ••• menu (share, live link, edit match, team colours, scorer settings) on the right.
- Competition name, small. Then the period name (gold) and the big clock. During a break the clock shows how long the last half ran, e.g. "Full Time · 31 min", never 00:00.
- Two team cards, stacked. Each: team name centred on top; then **green goal flag · score with the total underneath · white point flag** in one row; one **More** button below. No two-pointer (orange) flag on the card.
- Thumb zone at the bottom: the last event (with Undo and Details for a few seconds after each entry), and one big button that always says the next step (Start 1st Half, End 1st Half, Start 2nd Half, End 2nd Half, Start Extra Time, ...), with a pause/resume button beside it during play. Flags are disabled when the ball isn't in play.

**Recording a score**
1. Tapping a flag counts the score immediately, at that moment.
2. The scorer sheet then opens (unless switched off for that team):
   - **Point / 2-Pointer** switch at the top (not for goals);
   - how it was taken as chips: From play, Free, 45 (65 in hurling/camogie), Penalty, Mark, Sideline;
   - the **team sheet** to pick the scorer: laid out like the pitch, forwards at the top down to the goalkeeper, subs 16-30 below. Each player shows number, first name and surname (surnames are often shared). Unnamed players show the number only;
   - "Add note", collapsed until wanted.
3. Picking a player only highlights them (tap again to clear, or tap another). **Nothing is saved until Done**, so a wrong pick is just a re-tap.
4. "Undo point" (top left) removes the score. Dismissing the sheet keeps the score without a scorer.
- The sheet opens for **both teams** by default; the owner usually knows the home team's names and sometimes only the opposition's numbers. Each team has a "stop asking for scorers" switch (in the sheet and the ••• menu).
- Scores are linked to the player, not a written name, so names added to a team sheet later appear on scores already recorded.

**Other events**
- **More** lists Miss, Foul, Kickout, Substitution and Note (Team sheet comes with Phase 3). Each records at the tap, then opens its sheet; Undo and Details on the last-event card work for all of them.
- **Miss** uses the same sheet as a score: Wide / Saved / Short / Post at the top, then how it was taken and the player.
- **Foul**: Free / Penalty, a card chip (none, yellow, black, red) and who fouled; `side` is the team that conceded it. A card is always part of a foul, so there is no separate Card entry.
- **Kickout**: the team taking it; recorded as won, the sheet switches to lost (a lost kickout has no player).
- **Substitution**: one team sheet; pick the player coming off, then it moves on to the player coming on. Picking the same player for both moves them across.
- **Note**: a team's from More, the match's from the ••• menu. The text is saved however the sheet closes; Cancel or blank text deletes it.

## Commands

- `MatchCore` tests: `cd MatchCore && swift test` (macOS or Linux). Needs Swift 6.2 or later; the project uses Swift 6.4 (Xcode 27 on the Mac).
- In a Claude Code cloud session (Linux), install Swift first if `swift` is missing - the environment's network allows `download.swift.org`:
  ```bash
  apt-get install -y -qq binutils libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev \
    libsqlite3-0 libstdc++-13-dev libxml2-dev libncurses-dev libz3-dev pkg-config tzdata unzip zlib1g-dev
  cd /opt && curl -fsSL https://download.swift.org/swift-6.4.0-release/ubuntu2404/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-ubuntu24.04.tar.gz | tar xz
  ln -sf /opt/swift-6.4.0-RELEASE-ubuntu24.04/usr/bin/* /usr/local/bin/
  ```
- CI (`.github/workflows/ci.yml`) runs on every PR and push to `main`: `matchcore-linux` runs `swift test` in the `swift:6.4` container; `app-macos` runs `swift test`, then `xcodebuild test` (the app's `MatchTrackerTests`) on an available iPhone simulator. The `MatchTracker` scheme is shared (`xcshareddata/`) so CI can see it; keep it committed.
- App: build and test from Xcode (⌘U), or `xcodebuild test -project MatchTracker/MatchTracker.xcodeproj -scheme MatchTracker -destination 'platform=iOS Simulator,name=<iPhone>'`, where `<iPhone>` is one listed by `xcrun simctl list devices available iPhone`.
