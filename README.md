# MatchTracker for iOS

A native SwiftUI app for tracking Gaelic games matches - Football, Hurling, Ladies Football and Camogie - live from the sideline: the match clock, scores, cards, substitutions, notes and statistics.

Work in progress. See [`PLAN.md`](PLAN.md) for what's done and what's next.

## Layout

- `MatchCore/` - a Swift package with all the match logic (model, scoring, periods, event order, stats). Foundation only, so it builds and tests on macOS and Linux.
- `MatchTracker/` - the iOS app (SwiftUI, SwiftData), built on `MatchCore`.

## Building

- **Logic tests:** `cd MatchCore && swift test` (Swift 6.2).
- **App:** open `MatchTracker/MatchTracker.xcodeproj` in Xcode 26 or later and run. iOS 17 or later.

## Contributing

[`CLAUDE.md`](CLAUDE.md) holds the architecture, rules and conventions; [`PLAN.md`](PLAN.md) holds the decisions and the phased plan.
