# MatchTracker iOS - Plan

Rebuild the MatchTracker PWA as a native SwiftUI iOS app, with the PWA as the specification. Code is written mostly in Claude in Xcode; this repo on GitHub is the single shared place for the code, the rules (`CLAUDE.md`) and this plan. Tick items off as they land.

## Decisions

| Decision | Choice |
| --- | --- |
| Approach | Native SwiftUI rewrite (not a web-view wrapper) |
| Minimum iOS | 17 |
| Persistence | SwiftData, single store |
| Domain logic | `MatchCore` local Swift package, Foundation only |
| Migration for existing users | Import the PWA's JSON export |
| Live sharing | Keep Firebase, compatible with the PWA's `live.html` viewer |
| v1 extras | Live Activity, haptics, keep screen awake |

Open questions:
- Two-pointers for Ladies Football too, or Football only? (The PWA disagrees with itself.)
- Is the original Swift app's source still around? The PWA's enums say they mirror it.

## Workflow

1. Pick the next unticked item below.
2. Build it in Claude in Xcode on a branch.
3. Push and open a PR. Ask a Claude Code session to review it if useful.
4. Merge, tick the item here.

## Phase 0: Setup

- [x] Create the GitHub repo
- [x] Add `CLAUDE.md` and `PLAN.md`
- [ ] Install the Claude GitHub App on the repo (so Claude Code sessions can open it)
- [x] Clone the repo on the Mac and create the Xcode project **inside the cloned folder**: iOS App, SwiftUI, SwiftData, product name `MatchTracker`. Untick "Create Git repository" - the folder already is one
- [x] Add a local Swift package `MatchCore` at the repo root (File > New > Package) and link it to the app target
- [ ] Export a few real matches from the PWA into `MatchCore/Tests/MatchCoreTests/Fixtures/`

## Phase 1: Domain (`MatchCore`)

- [ ] Enums with the PWA's exact raw values
- [ ] Models: `Match`, `Team`, `Player`, `MatchEvent`, `PlayerPanel`, export envelope
- [ ] JSON decode/encode that round-trips the fixtures (string-or-number ids, nulls, unknown keys)
- [ ] Score calculation per match type
- [ ] Period state machine, `isPlayingPeriod`, automatic period-end events
- [ ] Event sorting by period, then time
- [ ] Panel normalisation (30 fixed slots, legacy panels)
- [ ] Import analysis: new / identical / conflicting
- [ ] Stats: shooting accuracy, scorers

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

- [ ] Export via `fileExporter` / `ShareLink`, file only
- [ ] Import with conflict-resolution screen
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
