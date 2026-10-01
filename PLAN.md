# MatchTracker iOS - Plan

Rebuild the MatchTracker PWA as a native SwiftUI iOS app. The PWA defines what the app does and the sport's rules; the iOS design, model and UI are native. Code is written mostly with Claude Code in Terminal; this repo on GitHub is the single shared place for the code, the rules (`CLAUDE.md`) and this plan. Tick items off as they land.

## Decisions

| Decision | Choice |
| --- | --- |
| Approach | Native SwiftUI rewrite (not a web-view wrapper) |
| Minimum iOS | 17 |
| Persistence | SwiftData, single store |
| Domain logic | `MatchCore` local Swift package, Foundation only |
| Data model | Native Swift model; PWA format only inside an importer |
| Migration for existing users | Import the PWA's JSON backup (one-way; the app exports its own format) |
| Live sharing | Keep Firebase, compatible with the PWA's `live.html` viewer |
| v1 extras | Live Activity, haptics, keep screen awake |
| Two-pointers | Football and Ladies Football |

## Workflow

Claude Code in Terminal does the work; Xcode is for looking at and running the app.

1. In Terminal, in the repo folder, run `claude` and ask for the next unticked item below. It reads `CLAUDE.md` automatically.
2. Claude Code pulls, branches, writes the code and tests, builds, and fixes errors.
3. Check the result in Xcode: Previews, the Simulator, or your phone. Ask for changes in Terminal.
4. Claude Code commits, pushes and opens a PR. Merge it on GitHub and tick the item here.

Don't let Claude Code and Claude in Xcode edit the same files at the same time. Decisions that matter go into `CLAUDE.md` or this file, not just a chat.

## Phase 0: Setup

- [x] Create the GitHub repo
- [x] Add `CLAUDE.md` and `PLAN.md`
- [x] Install the Claude GitHub App on the repo (so Claude Code sessions can open it)
- [x] Clone the repo on the Mac and create the Xcode project **inside the cloned folder**: iOS App, SwiftUI, SwiftData, product name `MatchTracker`. Untick "Create Git repository" - the folder already is one
- [x] Add a local Swift package `MatchCore` at the repo root (File > New > Package) and link it to the app target
- [x] Export a few real matches from the PWA into `MatchCore/Tests/MatchCoreTests/Fixtures/`

## Phase 1: Domain (`MatchCore`)

- [x] Enums with the PWA's exact raw values
- [x] PWA backup types that round-trip the fixture (string-or-number ids, nulls, unknown keys)
- [ ] Move the PWA types into `Sources/MatchCore/PWA/` and rename them `PWABackup`, `PWAMatch`, `PWATeam`, `PWAPlayer`, `PWAEvent`, `PWAPanel`, `PWAPanelPlayer`; keep their round-trip tests passing
- [ ] Native model in `Sources/MatchCore/Model/`: `Match`, `Team`, `Player`, `MatchEvent` (+ `kind` enum), `MatchClock`, `PlayerPanel`, typed IDs (see `CLAUDE.md`)
- [ ] PWA importer: `PWABackup` -> native model, tested against the fixture (all 71 matches and 6 panels convert; every match's score is unchanged)
- [ ] Score calculation per match type
- [ ] Period state machine, playing periods, automatic period-end events
- [ ] Event sorting by period, then time
- [ ] Panels: 30 fixed slots; legacy panels normalised
- [ ] Import analysis: new / identical / conflicting
- [ ] Stats: shooting accuracy, scorers
- [ ] The app's own backup format (versioned JSON of the native model)

## Phase 2: Core tracking (MVP)

- [ ] SwiftData models and mapping to/from `MatchCore`
- [ ] Home and match list with filter
- [ ] Match create/edit form
- [ ] Match details: scoreboard, wall-clock timer, period transitions
- [ ] Score entry (goal, point, two-pointer, misses, shot types)
- [ ] Foul/card, kickout, substitution and note entry
- [ ] Events list with edit/delete
- [ ] Time/period editor
- [ ] Add GitHub Actions CI (macOS: build app, run tests)

## Phase 3: Players

- [ ] Team rosters (30 players, editable names)
- [ ] Player panels: list and editor
- [ ] Import a panel into a team, before throw-in only
- [ ] Remember the last panel per team per match

## Phase 4: Data

- [ ] Export the app's own backup format via `fileExporter` / `ShareLink`, file only
- [ ] Import a PWA backup or the app's own backup, with conflict-resolution screen
- [ ] Last-backup indicator

## Phase 5: Sharing and stats

- [ ] Statistics screen
- [ ] 800x800 event share images (`ImageRenderer`)
- [ ] Firebase live sharing, compatible with `live.html`

## Phase 6: iOS extras

- [ ] Live Activity and Dynamic Island (score, period, running clock)
- [ ] Haptics on score entry; keep screen awake during a live match
- [ ] v1.1: iCloud sync (CloudKit), widgets, Apple Watch app, App Intents / Siri, iPad layout

## Phase 7: Release

- [ ] TestFlight, tried at a real match
- [ ] App Store listing, screenshots, privacy manifest (disclose the Firebase share link)
- [ ] Decide the PWA's future; keep its export format stable while both exist
