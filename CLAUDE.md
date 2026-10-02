# CLAUDE.md

Guidance for Claude (Claude in Xcode and Claude Code) working in this repository.

## Project

MatchTracker for iOS: a native SwiftUI app for tracking Gaelic games matches (Football, Hurling, Ladies Football, Camogie) live from the sideline - timer, scoring, events, players, stats and sharing.

It replaces the PWA at [`alancullinan/matchtrackerpwa`](https://github.com/alancullinan/matchtrackerpwa) (live at matchtracker.club). **The PWA is the spec for what the app does and for the sport's rules - not for how the app is built or how it looks.** Read its `script.js` to learn a behaviour; then design the iOS version natively. Deviate from the PWA wherever it makes a better iOS app, and record the deviation here or in `PLAN.md`.

Other MatchTracker repos exist (`MatchTracker`, the original 2025 Swift app, and `MatchTrackerV2`, an earlier rebuild). **Do not use them as a reference or copy from them** - the PWA is the only spec.

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
    PWA/                        PWA backup format + importer (the only place PWA quirks live)
  Tests/MatchCoreTests/
    Fixtures/                   real PWA export JSONs (anonymised if the repo is public)
CLAUDE.md, PLAN.md              repo root - Claude in Xcode does not show these in the project
                                navigator; read them from here at the start of each task
```

The repo must not live in an iCloud-synced folder (Desktop, Documents, iCloud Drive): git commits fail with "Resource deadlock avoided" and the repo can be corrupted. Keep it in e.g. `~/Developer/MatchTrackerIOS`.

### MatchCore rules
- **Foundation only.** Never import SwiftUI, SwiftData, UIKit or any Apple-platform-only framework. It must build and test with `swift test` on macOS *and* Linux, so Claude Code cloud sessions can run its tests.
- Plain `Codable`, `Sendable`, value-type models. The app target maps them to SwiftData; nothing in `MatchCore` knows about storage.
- **The native model is designed for Swift, not copied from the PWA's JSON.** Make invalid states unrepresentable:
  - `MatchEvent` holds the shared fields (id, period, time, note) plus a `kind` enum with one case per event type, each carrying only its own data (a shot has an outcome and shot type; a card has a card type). No bag of optional fields.
  - IDs are random `UUID`s, wrapped in small typed IDs. Records imported from the PWA also keep their PWA id as `legacyID`, only so the import can skip a match it has already brought in.
  - Teams are referenced by side (`.team1` / `.team2`), not by a team-id string.
  - An unnamed player has `name == nil`; never a `No.N` placeholder.
  - A period-end event records the period that **ended** (e.g. `.firstHalf`).
  - The clock is `period` + seconds banked + `runningSince: Date?`, so running time is always derived from the wall clock.
  - `note` is a shared optional field on every event, not only `.note` events: the PWA lets shots and substitutions carry notes too.
  - `.card` exists for older standalone card events; new cards are recorded on a `.foul`.
  - The last panel imported into a team is `Team.lastPanelID`.
  - Starting a running clock or pausing a paused one changes nothing, so a double-tap or a repeated pause can never add time twice.
- **All match logic lives here**, not in views: scoring, period transitions, event sorting, stats, panel normalisation. Views call it; they do not re-implement it.
- Every logic change comes with a test.

### App rules
- iOS 17+, SwiftUI, `NavigationStack`, `@Observable`.
- **One persistent store: SwiftData, synced to the user's private iCloud database (CloudKit).** iCloud sync is part of that store, not a second one. Never add another store, cache or mirror of match data - the PWA lost recent matches to exactly that (two stores, read from the stale one).
- **SwiftData models must stay CloudKit-compatible**, or sync silently stops working:
  - every stored property is optional or has a default value;
  - no `@Attribute(.unique)` - uniqueness is enforced in code;
  - every relationship is optional, and no `.deny` delete rules;
  - schema changes are additive only (add properties; never rename or remove one once shipped).
- Each user's data lives in their own iCloud account; there is no shared server. Live score sharing (Firebase) is separate and sends only a snapshot.
- Keep a match **self-contained** (its teams, players and events belong to it) so a single match can be shared later. How is undecided - see `PLAN.md`.
- Never delete data that has not been verified - e.g. a migration writes, reads back and compares before removing anything.

## Importing the owner's PWA data (one-time)

Only the owner has used the PWA, so PWA import is a **one-time migration** of their data, not a user-facing feature. Everything PWA-specific lives in `Sources/MatchCore/PWA/`:

- **`PWA*` types** (`PWABackup`, `PWAMatch`, `PWAEvent`, ...) mirror the PWA's JSON exactly and are tested to round-trip the fixture. They are never used by the app or stored.
- **The importer** converts a `PWABackup` into native models. It is tested against `Fixtures/pwa-backup.json`: every match, event and panel converts, and each match's score is the same before and after. Matches whose `legacyID` already exists are skipped, so running it twice is harmless. No conflict resolution.
- The app never writes PWA files. The one PWA-shaped output is live sharing: it writes the PWA's **live-score snapshot** - the flat object built by `buildLivePayload()` in the PWA's `script.js` (team names, totals, goals/points per team, period, clock fields, last score) - so `live.html` keeps working.

Traps in the PWA format, all handled in `PWA/` and nowhere else:
- `MatchPeriod` raw values are display strings (`"1st Half"`, `"Half Time"`, ...); other enums are camelCase (`foulConceded`, `twoPointer`, `ladiesFootball`). The shared enums in `MatchCore` keep these raw values, which is harmless.
- IDs are strings (`"1727771234567-123456"`) except period-end events, whose ids are numbers.
- Events are one flat object with many `null` fields; period-end events omit most fields. Unknown keys must not fail an import.
- A PWA `periodEnd` event's `period` is the period being **entered** (`"Half Time"`); the importer converts it to the period that ended. `"Match Over"` ends Extra Time 2nd Half only if the match went to extra time; straight after Full Time (extra time off) it ends nothing, so the importer drops it with a warning.
- PWA dates are a bare `"YYYY-MM-DD"`; the importer stores midday on that day in the given time zone.
- Unnamed players are stored as `"No.<jersey number>"`; the importer converts that to `nil`.
- `timeElapsed` / `elapsedTime` are seconds within the period; `periodStartTimestamp` is epoch milliseconds or `null`.

## Behaviour that must carry over from the PWA

These are rules of the sport and lessons from real bugs - keep them whatever the UI looks like.

**Match logic**
- Scoring: goal = 3, point = 1, two-pointer = 2. Two-pointers exist for Football and Ladies Football, not Hurling or Camogie (confirmed by the owner). In the PWA a two-pointer is recorded by tapping Point, then choosing "2 Pointer" in the score modal's Score Type toggle.
- Events can be recorded only in playing periods: 1st Half, 2nd Half, Extra Time 1st Half, Extra Time 2nd Half.
- Ending a playing period automatically records a period-end event with the period that ended and its time. The score at that point is derived from the earlier events, never stored, so it stays correct after edits.
- Events sort by period order, then time; newest first in the event list, oldest first for exports and sharing. A period end is always last in its period, even if an edited event's time is later. Events at the same moment keep recorded order. Sorting is computed (`Match.eventsInOrder`), so it stays correct after time or period edits.
- Periods (`MatchPeriods.swift`): `start` begins the next playing period from a break at 0:00, or resumes a paused one; `endPeriod` records the period end and moves to the following break (Match Over after Extra Time 2nd Half); `finish` ends the match at Full Time. Periods have no set length: the clock runs until the period is ended, and any match can go to extra time. Each returns `false` and changes nothing when it doesn't apply. Unlike the PWA, finishing at Full Time records no event: no playing period ended there.
- The timer is **wall-clock based**: running time = now − `periodStartTimestamp`, never a tick counter. This is what lets a Live Activity show a clock without the app running.

**Players and panels**
- Each team has 30 players, jersey numbers 1-30; names are optional.
- A panel has **exactly 30 fixed slots**; the slot is the jersey number. Empty slots are kept; panels are never sorted or compacted. Legacy panels (just `{id, name}`) are normalised into slots 1..N in stored order.
- Panel import into a team is allowed only before throw-in, overwrites names in place and **never regenerates player ids** (events reference them).

**Data safety**
- iCloud sync is not a backup: deleting a match on one device deletes it everywhere. Deleting a match always needs a confirmation.
- If an export to Files is added later, only a **completed** export counts as a backup (a cancelled share sheet records nothing), and it shares the file only - no title or text - so "Save to Files" saves exactly one file.

## Design principles (UI)

The app is used one-handed, on a sideline, often in rain or sun, while watching the game. Design for that rather than copying the PWA's screens:

- **Fewest taps per event.** The most common actions (score, wide, card, substitution) are reachable from the match screen.
- **Undo, not confirmations.** Record immediately and offer undo ("Point - No.11 · Undo") instead of confirm dialogs. Keep confirmations only for destructive, hard-to-undo actions (deleting a match).
- **Big targets, high contrast**, readable in sunlight; nothing important behind a small icon.
- **Native iOS patterns**: sheets, swipe actions, context menus, haptics, Live Activity - not web-style modals with Cancel/Done bars everywhere.
- Port the PWA's **tasks** (record a score, make a substitution, end a period), not its layouts.

## Commands

- `MatchCore` tests: `cd MatchCore && swift test` (macOS or Linux).
- App: build and test from Xcode (⌘U), or `xcodebuild test -project MatchTracker/MatchTracker.xcodeproj -scheme MatchTracker -destination 'platform=iOS Simulator,name=iPhone 17'`.
