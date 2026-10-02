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
- Work on a branch and open a PR; keep PRs to one checklist item or a small group of them.
- Never include an AI model name in commits, PRs or code comments.

## Architecture

```
MatchTracker/                   Xcode project folder
  MatchTracker.xcodeproj        open this in Xcode
  MatchTracker/                 iOS app target sources (SwiftUI, SwiftData)
MatchCore/                      local Swift package - the domain layer (linked as ../MatchCore)
  Package.swift
  Sources/MatchCore/
    Model/                      the app's own native model and logic
    PWA/                        one-off importer for the owner's PWA backup (isolated; see below)
  Tests/MatchCoreTests/
    Fixtures/                   the owner's PWA backup, anonymised - used only by importer tests
CLAUDE.md, PLAN.md              repo root - Claude in Xcode does not show these in the project
                                navigator; read them from here at the start of each task
```

The repo must not live in an iCloud-synced folder (Desktop, Documents, iCloud Drive): git commits fail with "Resource deadlock avoided" and the repo can be corrupted. Keep it in e.g. `~/Developer/MatchTrackerIOS`.

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
- Every logic change comes with a test.

### App rules
- iOS 17+, SwiftUI, `NavigationStack`, `@Observable`.
- **One persistent store: SwiftData, synced to the user's private iCloud database (CloudKit).** iCloud sync is part of that store, not a second one. Never add another store, cache or mirror of match data - a second store that falls out of step silently loses recent matches (it happened in the PWA).
- **SwiftData models must stay CloudKit-compatible**, or sync silently stops working:
  - every stored property is optional or has a default value;
  - no `@Attribute(.unique)` - uniqueness is enforced in code;
  - every relationship is optional, and no `.deny` delete rules;
  - schema changes are additive only (add properties; never rename or remove one once shipped).
- Each user's data lives in their own iCloud account; there is no shared server. Live score sharing, if added, sends only a snapshot of the score, never the match data.
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

## Commands

- `MatchCore` tests: `cd MatchCore && swift test` (macOS or Linux).
- App: build and test from Xcode (⌘U), or `xcodebuild test -project MatchTracker/MatchTracker.xcodeproj -scheme MatchTracker -destination 'platform=iOS Simulator,name=iPhone 17'`.
