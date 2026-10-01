# CLAUDE.md

Guidance for Claude (Claude in Xcode and Claude Code) working in this repository.

## Project

MatchTracker for iOS: a native SwiftUI app for tracking Gaelic games matches (Football, Hurling, Ladies Football, Camogie) live from the sideline - timer, scoring, events, players, stats and sharing.

It is a rewrite of the PWA at [`alancullinan/matchtrackerpwa`](https://github.com/alancullinan/matchtrackerpwa) (live at matchtracker.club). **The PWA is the specification**: when behaviour is unclear, read its `script.js` and match it unless this file or `PLAN.md` says otherwise.

Other MatchTracker repos exist (`MatchTracker`, the original 2025 Swift app, and `MatchTrackerV2`, an earlier rebuild). **Do not use them as a reference or copy from them** - the PWA is the only spec.

`PLAN.md` holds the phased plan and checklists. Tick items off there as work lands.

## How we work

- Most coding happens in **Claude in Xcode** on a Mac (builds, Previews, Simulator, tests).
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
  Tests/MatchCoreTests/
    Fixtures/                   real PWA export JSONs (anonymised if the repo is public)
CLAUDE.md, PLAN.md              repo root - Claude in Xcode does not show these in the project
                                navigator; read them from here at the start of each task
```

The repo must not live in an iCloud-synced folder (Desktop, Documents, iCloud Drive): git commits fail with "Resource deadlock avoided" and the repo can be corrupted. Keep it in e.g. `~/Developer/MatchTrackerIOS`.

### MatchCore rules
- **Foundation only.** Never import SwiftUI, SwiftData, UIKit or any Apple-platform-only framework. It must build and test with `swift test` on macOS *and* Linux, so Claude Code cloud sessions can run its tests.
- Plain `Codable`, `Sendable`, value-type models. The app target maps them to SwiftData; nothing in `MatchCore` knows about storage.
- **All match logic lives here**, not in views: scoring, period transitions, event sorting, stats, panel normalisation, import analysis. Views call it; they do not re-implement it.
- Every logic change comes with a test.

### App rules
- iOS 17+, SwiftUI, `NavigationStack`, `@Observable`.
- **One persistent store (SwiftData).** Never add a second store, cache or mirror of match data. The PWA lost users' recent matches to exactly that (two stores, read from the stale one).
- Never delete data that has not been verified - e.g. a migration writes, reads back and compares before removing anything.

## JSON compatibility with the PWA

Users move from the PWA by exporting a backup and importing it here, so `MatchCore` must read (and write) the PWA's export format **exactly**. Golden fixtures in `MatchCore/Tests/MatchCoreTests/Fixtures/` must round-trip.

Export envelope:
```json
{ "version": "1.0.0", "exportDate": "ISO-8601", "matches": [...], "matchCount": 0,
  "playerPanels": [...], "panelCount": 0, "lastSelectedPanels": {...} }
```

Traps in that format:
- **Enum raw values are the PWA's strings, not Swift-style names.** `MatchPeriod` raw values are display strings: `"Not Started"`, `"1st Half"`, `"Half Time"`, `"2nd Half"`, `"Full Time"`, `"Extra Time 1st Half"`, `"Extra Time Half Time"`, `"Extra Time 2nd Half"`, `"Match Over"`. Others are camelCase: event `type` (`shot`, `substitution`, `kickout`, `card`, `foulConceded`, `note`, `periodEnd`), `shotOutcome` (`goal`, `point`, `twoPointer`, `wide`, `saved`, `droppedShort`, `offPost`), `shotType` (`fromPlay`, `free`, `penalty`, `fortyFive`, `sixtyFive`, `sideline`, `mark`), `cardType` (`yellow`, `red`, `black`), `foulOutcome` (`free`, `penalty`), `matchType` (`football`, `hurling`, `ladiesFootball`, `camogie`).
- **IDs are usually strings (`"1727771234567-123456"`) but period-end event ids are numbers** (`Date.now()`). Decode an id as string-or-number.
- Event fields are often present as `null` (`player2Id`, `foulOutcome`, `cardType`, `wonKickout`, `noteText`); period-end events omit most fields entirely. Decode leniently; unknown keys must not fail the import.
- Times: `timeElapsed` / `elapsedTime` are seconds within the current period; `periodStartTimestamp` is epoch milliseconds or `null`.

## Behaviour that must carry over from the PWA

**Match logic**
- Scoring: goal = 3, point = 1, two-pointer = 2. Two-pointers exist for Football and Ladies Football, not Hurling or Camogie (confirmed by the owner). In the PWA a two-pointer is recorded by tapping Point, then choosing "2 Pointer" in the score modal's Score Type toggle.
- Events can be recorded only in playing periods: 1st Half, 2nd Half, Extra Time 1st Half, Extra Time 2nd Half.
- Ending a period that leads into Half Time, Full Time, Extra Time Half Time or Match Over creates a `periodEnd` event automatically. Its `period` is the period being **entered**; its `timeElapsed` is the time of the period just ended.
- Events sort by period order, then `timeElapsed`; newest first in the event list, oldest first for exports and sharing. Sorting must stay correct after time or period edits.
- The timer is **wall-clock based**: running time = now − `periodStartTimestamp`, never a tick counter. This is what lets a Live Activity show a clock without the app running.

**Players and panels**
- Each team has 30 players, jersey numbers 1-30. The default name `No.N` is a sentinel the PWA compares against; in Swift prefer an explicit "unnamed" state, but write `No.N` back out in exports.
- A panel has **exactly 30 fixed slots**; the slot is the jersey number. Empty slots are kept; panels are never sorted or compacted. Legacy panels (just `{id, name}`) are normalised into slots 1..N in stored order.
- Panel import into a team is allowed only before throw-in, overwrites names in place and **never regenerates player ids** (events reference them).

**Backup and import**
- Only a **completed** export records `lastBackupAt`; a cancelled share sheet records nothing.
- Export shares the file only (no title or text), so "Save to Files" saves exactly one file.
- Import is two-phase: a pure analysis (no writes) then an apply. Incoming records are **new** (import), **identical** (skip silently) or **conflicting** (same id, different content).
- Each conflict defaults to keeping the device copy; the destructive choice is never a fallback. Choosing the backup replaces the whole match - never an event-level merge. Cancelling writes nothing at all.

## Commands

- `MatchCore` tests: `cd MatchCore && swift test` (macOS or Linux).
- App: build and test from Xcode (⌘U), or `xcodebuild test -project MatchTracker/MatchTracker.xcodeproj -scheme MatchTracker -destination 'platform=iOS Simulator,name=iPhone 17'`.
