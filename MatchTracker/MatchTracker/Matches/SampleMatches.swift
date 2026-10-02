#if DEBUG
import Foundation
import MatchCore
import SwiftData
import SwiftUI

/// Varied matches for Previews and tests: every kind of state a row can show.
enum SampleMatches {
    /// How many of `insert`'s records can be read (the last one is deliberately broken).
    static let readableCount = 6

    static func insert(into context: ModelContext, now: Date = .now) throws {
        let day: TimeInterval = 24 * 60 * 60

        // Not started, with long names that need two lines.
        try context.store(Match.new(
            matchType: .hurling, team1Name: "Ballyboden St. Enda's", team2Name: "Kilmacud Crokes",
            competition: "Senior Hurling Championship", date: now.addingTimeInterval(day)
        ))

        // Live in the second half.
        var live = Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "St. Vincent's",
                             competition: "Senior Football League", date: now)
        live.start(at: now.addingTimeInterval(-3000))
        live.record(shot(.team1, .goal), at: now.addingTimeInterval(-2900))
        live.record(shot(.team2, .twoPointer), at: now.addingTimeInterval(-2500))
        live.endPeriod(at: now.addingTimeInterval(-1200))
        live.start(at: now.addingTimeInterval(-600))
        live.record(shot(.team2, .point), at: now.addingTimeInterval(-300))
        live.team1.colors = TeamColors(.orange, .green)
        live.team2.colors = TeamColors(.navy, .blue)
        try context.store(live)

        // Paused in the first half.
        var paused = Match.new(matchType: .ladiesFootball, team1Name: "Foxrock-Cabinteely", team2Name: "Seán Mac Cumhaills",
                               competition: "Junior B", date: now.addingTimeInterval(-60))
        paused.start(at: now.addingTimeInterval(-900))
        paused.record(shot(.team1, .point), at: now.addingTimeInterval(-800))
        paused.pause(at: now.addingTimeInterval(-500))
        // Only one team has colours.
        paused.team1.colors = TeamColors(.white)
        try context.store(paused)

        // Full time, a week ago.
        var fullTime = Match.new(matchType: .camogie, team1Name: "Lucan Sarsfields", team2Name: "Cuala",
                                 competition: "Minor Cup", date: now.addingTimeInterval(-7 * day))
        play(&fullTime, from: now.addingTimeInterval(-7 * day), team1: [.goal, .point, .point], team2: [.point])
        fullTime.team1.colors = TeamColors(.green, .gold)
        fullTime.team2.colors = TeamColors(.red, .white)
        try context.store(fullTime)

        // Full time after extra time, no competition.
        var extraTime = Match.new(matchType: .football, team1Name: "Thomas Davis", team2Name: "Ballymun Kickhams",
                                  date: now.addingTimeInterval(-14 * day))
        play(&extraTime, from: now.addingTimeInterval(-14 * day), team1: [.point, .point], team2: [.twoPointer], extraTime: true)
        try context.store(extraTime)

        // An earlier match with no score.
        try context.store(Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B",
                                    competition: "Friendly", date: now.addingTimeInterval(-30 * day)))

        // A record that can't be read, as if written by a newer version of the app.
        let unreadable = try context.store(Match.new(matchType: .hurling, team1Name: "Raheny", team2Name: "Craobh Chiaráin",
                                                     competition: "League", date: now.addingTimeInterval(-60 * day)))
        unreadable.clockPeriod = "penaltyShootout"
    }

    private static func shot(_ side: TeamSide, _ outcome: ShotOutcome) -> MatchEvent.Kind {
        .shot(side: side, player: nil, outcome: outcome, type: .fromPlay)
    }

    /// Plays a whole match from `start`, scoring in the first half.
    private static func play(_ match: inout Match, from start: Date, team1: [ShotOutcome], team2: [ShotOutcome], extraTime: Bool = false) {
        var time = start
        func next(_ seconds: TimeInterval) -> Date { time = time.addingTimeInterval(seconds); return time }

        match.start(at: time)
        for outcome in team1 { match.record(shot(.team1, outcome), at: next(60)) }
        for outcome in team2 { match.record(shot(.team2, outcome), at: next(60)) }
        match.endPeriod(at: next(1800))
        match.start(at: next(600))
        match.endPeriod(at: next(1800))
        guard extraTime else { return }
        match.start(at: next(300))
        match.endPeriod(at: next(600))
        match.start(at: next(120))
        match.endPeriod(at: next(600))
    }
}

/// Previews with the sample matches.
struct SampleMatchesPreview: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let container = try Store.container(inMemory: true)
        try SampleMatches.insert(into: container.mainContext)
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

/// Previews with an empty store.
struct EmptyStorePreview: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        try Store.container(inMemory: true)
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    static var sampleMatches: Self { .modifier(SampleMatchesPreview()) }
    static var emptyStore: Self { .modifier(EmptyStorePreview()) }
}
#endif
