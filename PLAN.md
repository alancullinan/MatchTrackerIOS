# MatchTracker iOS - Plan

A native SwiftUI iOS app for tracking Gaelic games matches, succeeding the owner's unreleased PWA. The PWA is a reference for features and the sport's rules, not a constraint; the app is designed for iOS first. Code is written mostly with Claude Code in Terminal; this repo on GitHub is the single shared place for the code, the rules (`CLAUDE.md`) and this plan. Tick items off as they land.

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Approach | Native SwiftUI rewrite (not a web-view wrapper) | A wrapper keeps WebKit's storage limits and web quirks, can't easily use iOS features (Live Activities, widgets, Watch, haptics), and risks App Store rejection as "just a website" |
| Minimum iOS | 17 | Needed for SwiftData and `@Observable`, while still running on older phones; Xcode's default (26.2) would have left those out |
| Persistence | SwiftData, synced to each user's private iCloud database (CloudKit) | One store avoids the PWA's data-loss bug (two stores out of step). iCloud syncs across devices and survives a lost phone, with no server, account system or cost, and works offline on the sideline |
| Paid developer account | Not until Phase 4 (iCloud) | A free Apple ID covers building and running on the Simulator and your own phone; the paid account is only needed for iCloud, TestFlight and the App Store |
| Domain logic | `MatchCore` local Swift package, Foundation only | Logic can be tested in seconds without the Simulator, builds and tests on Linux so cloud sessions can run the tests, and can be reused by a Watch app, widgets and Live Activities |
| Data model | Native Swift model; anything PWA-specific stays inside the isolated importer | Designed so invalid states can't exist (each event type carries only its own data); the PWA was never released, so it isn't worth bending the model for it |
| Migrating PWA data | Optional one-time import of the owner's own matches; low priority | Only the owner ever used the PWA |
| Periods | No set length; any match can go to extra time; no step to finish a match | The clock runs until a period is ended, and extra time depends on the score on the day. Full Time is the end unless extra time is started, so a separate "finish" would only be an extra tap |
| Sharing a match | Later. Approach undecided: CloudKit sharing, or a read-only link like live sharing | Not needed yet; matches are kept self-contained so it stays possible |
| Live sharing | Later. Approach undecided; the PWA's Firebase viewer (`live.html`) is one option, not a requirement | Not needed for v1; to be decided on its own merits rather than for PWA compatibility |
| v1 extras | Live Activity, haptics, keep screen awake | The biggest gains on the sideline for little work: score and clock on the Lock Screen, confirmation without looking, and no screen locking mid-match. Widgets, Watch, Siri and iPad wait for v1.1 |
| Two-pointers | Football and Ladies Football | Confirmed by the owner: both codes have the two-point score; Hurling and Camogie don't |
| Main tool | Claude Code in Terminal; Xcode for Previews, the Simulator and devices | Claude Code reads `CLAUDE.md` automatically, handles git and PRs, and runs builds and tests; GitHub is the shared record for every session |

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

- [x] Enums (now the app's own case names; the PWA's strings live in `PWA/`)
- [x] PWA backup types that round-trip the fixture (string-or-number ids, nulls, unknown keys)
- [x] Move the PWA types into `Sources/MatchCore/PWA/` and rename them `PWABackup`, `PWAMatch`, `PWATeam`, `PWAPlayer`, `PWAEvent`, `PWAPanel`, `PWAPanelPlayer`; keep their round-trip tests passing
- [x] Native model in `Sources/MatchCore/Model/`: `Match`, `Team`, `Player`, `MatchEvent` (+ `kind` enum), `MatchClock`, `PlayerPanel`, typed IDs (see `CLAUDE.md`)
- [x] One-time PWA importer: `PWABackup` -> native model, tested against the fixture (all 71 matches and 6 panels convert; every match's score is unchanged; re-running skips matches already imported)
- [x] Score calculation per match type
- [x] Period state machine, playing periods, automatic period-end events
- [x] Event sorting by period, then time
- [x] Panels: 30 fixed slots; legacy panels normalised (done in the importer, following the PWA's `normalizePanel`)
- [ ] Stats: shooting accuracy, scorers

## Phase 2: Core tracking (MVP)

- [ ] SwiftData models (CloudKit-compatible, see `CLAUDE.md`) and mapping to/from `MatchCore`; stored on the device only until iCloud is turned on in Phase 4
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

- [ ] Join the paid Apple Developer Program, then turn on iCloud in Xcode: MatchTracker target > Signing & Capabilities > **+ Capability > iCloud**, tick **CloudKit**, add container `iCloud.com.alancullinan.MatchTracker`; then **+ Capability > Background Modes**, tick **Remote notifications**. Set the store's `cloudKitDatabase` so SwiftData syncs
- [ ] iCloud sync status in Settings (signed out / syncing / up to date)
- [ ] Optional: export everything to Files as a backup

## Phase 5: Sharing and stats

- [ ] Statistics screen
- [ ] 800x800 event share images (`ImageRenderer`)
- [ ] Live score sharing (approach to decide)

## Phase 6: iOS extras

- [ ] Live Activity and Dynamic Island (score, period, running clock)
- [ ] Haptics on score entry; keep screen awake during a live match
- [ ] v1.1: widgets, Apple Watch app, App Intents / Siri, iPad layout

## Phase 7: Release

- [ ] TestFlight, tried at a real match
- [ ] App Store listing, screenshots, privacy manifest

## Later ideas

- [ ] If wanted: a hidden screen to run the PWA import once (the importer is already in `MatchCore`)
- [ ] Share a match with someone else (read-only first)
