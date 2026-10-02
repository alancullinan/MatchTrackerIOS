import Foundation
import Testing
@testable import MatchCore

private func shot(_ side: TeamSide, _ outcome: ShotOutcome) -> MatchEvent {
    MatchEvent(period: .firstHalf, time: 0, kind: .shot(side: side, player: nil, outcome: outcome, type: .fromPlay))
}

@Test func goalsArePointsWorthThree() {
    let score = Score(of: .team1, in: [shot(.team1, .goal), shot(.team1, .point), shot(.team1, .point)])
    #expect(score == Score(goals: 1, points: 2))
    #expect(score.total == 5)
}

@Test func aTwoPointerAddsTwoPoints() {
    let score = Score(of: .team2, in: [shot(.team2, .twoPointer), shot(.team2, .point)])
    #expect(score == Score(goals: 0, points: 3, twoPointers: 1))
    #expect(score.total == 3)
}

@Test func missesOtherTeamsAndOtherEventsDontCount() {
    let events = [
        shot(.team1, .wide), shot(.team1, .saved), shot(.team1, .droppedShort), shot(.team1, .offPost),
        shot(.team2, .goal),
        MatchEvent(period: .firstHalf, time: 0, kind: .foul(side: .team1, player: nil, outcome: .free, card: nil)),
        MatchEvent(period: .firstHalf, time: 0, kind: .periodEnd),
    ]
    #expect(Score(of: .team1, in: events) == Score())
    #expect(Score(of: .team2, in: events) == Score(goals: 1))
}

@Test func scoresReadGoalsThenPaddedPoints() {
    #expect(Score().description == "0-00")
    #expect(Score(goals: 1, points: 5).description == "1-05")
    #expect(Score(goals: 2, points: 14).description == "2-14")
}

@Test func matchScoreIsPerSide() {
    var match = Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: Date(timeIntervalSince1970: 0))
    match.events = [shot(.team1, .goal), shot(.team2, .twoPointer), shot(.team2, .point)]
    #expect(match.score(.team1) == Score(goals: 1))
    #expect(match.score(.team2) == Score(points: 3, twoPointers: 1))
}

@Test func onlyFootballCodesHaveTwoPointers() {
    #expect(MatchType.allCases.filter(\.allowsTwoPointers) == [.football, .ladiesFootball])
}
