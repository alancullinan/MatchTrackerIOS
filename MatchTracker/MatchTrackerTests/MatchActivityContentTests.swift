import Foundation
import MatchCore
import Testing
@testable import MatchTracker

@MainActor
struct MatchActivityContentTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func newMatch() -> Match {
        var match = Match.new(matchType: .football, team1Name: "Na Fianna", team2Name: "Cuala",
                              competition: "Senior Football League", date: t0)
        match.team1.colors = TeamColors(.blue, .white)
        return match
    }

    @Test func aMatchIsLiveFromThrowInUntilFullTime() {
        var match = newMatch()
        #expect(!MatchActivityContent.isLive(match))
        match.start(at: at(0))
        #expect(MatchActivityContent.isLive(match))
        match.endPeriod(at: at(1800))
        #expect(MatchActivityContent.isLive(match), "It shows through half time")
        match.start(at: at(2400))
        match.endPeriod(at: at(4200))
        #expect(match.clock.period == .fullTime)
        #expect(!MatchActivityContent.isLive(match))
    }

    @Test func aRunningClockCountsUpFromWhenItReadZero() {
        var match = newMatch()
        match.start(at: at(0))
        match.pause(at: at(300))
        match.start(at: at(360))
        let state = MatchActivityContent.state(for: match)
        #expect(state.clockStartedAt == at(60))
        #expect(state.periodName == "1st Half")
    }

    @Test func aStoppedClockShowsItsText() {
        var match = newMatch()
        match.start(at: at(0))
        match.pause(at: at(605))
        #expect(MatchActivityContent.state(for: match).clockStartedAt == nil)
        #expect(MatchActivityContent.state(for: match).stoppedClock == "10:05")

        match.start(at: at(700))
        match.endPeriod(at: at(1960))
        let halfTime = MatchActivityContent.state(for: match)
        #expect(halfTime.stoppedClock == "31 min")
        #expect(halfTime.periodName == "Half Time")
        #expect(halfTime.lastEvent == "End of 1st Half")
    }

    @Test func teamsCarryTheirNameScoreAndColours() {
        var match = newMatch()
        match.start(at: at(0))
        match.record(.shot(side: .team1, player: nil, outcome: .goal, type: .fromPlay), at: at(60))
        match.record(.shot(side: .team1, player: nil, outcome: .twoPointer, type: .fromPlay), at: at(120))
        let state = MatchActivityContent.state(for: match)
        #expect(state.team1.name == "Na Fianna")
        #expect(state.team1.score == "1-02")
        #expect(state.team1.total == 5)
        #expect(state.team1.color == .init(red: 0.12, green: 0.31, blue: 0.75))
        #expect(state.team1.secondColor == .init(red: 1, green: 1, blue: 1))
        #expect(state.team2.color == nil)
        #expect(state.lastEvent == "2-Pointer · Na Fianna")
        #expect(MatchActivityContent.attributes(for: match).matchID == match.id.uuid)
    }
}
