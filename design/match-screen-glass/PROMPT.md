# Prompt for Claude Code

Open Xcode with the project (so Claude Code can reach Xcode's tools), then run `claude` from the repo root and paste:

---

Read `design/match-screen-glass/SPEC.md` and look at the screenshots and `match-view.html` in that folder. It's the owner-approved restyle of the match screen: the PLAN.md item "Another pass on the match screen's look".

Before writing code, read the current `MatchScreen/` views and `MatchTheme`. Then tell me:
- which files change;
- how the clock button's tap/hold logic will be structured;
- anything in the spec that conflicts with CLAUDE.md or needs a `MatchCore` change.

Then work through the three PRs in §7 of the spec, one at a time. Follow the repo's usual workflow (branch, tests, Simulator check against the screenshots, PR with the docs updates).
