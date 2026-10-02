import Foundation
import Testing
@testable import MatchCore

private func shot(_ side: TeamSide, _ player: PlayerID?, _ outcome: ShotOutcome, _ type: ShotType = .fromPlay, _ period: MatchPeriod = .firstHalf) -> MatchEvent {
    MatchEvent(period: period, time: 0, kind: .shot(side: side, player: player, outcome: outcome, type: type))
}

private func newMatch() -> Match {
    Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: Date(timeIntervalSince1970: 0))
}

@Test func teamShootingCountsEveryOutcome() {
    var match = newMatch()
    match.events = [
        shot(.team1, nil, .goal), shot(.team1, nil, .point), shot(.team1, nil, .twoPointer),
        shot(.team1, nil, .wide), shot(.team1, nil, .wide), shot(.team1, nil, .saved),
        shot(.team1, nil, .droppedShort), shot(.team1, nil, .offPost),
        shot(.team2, nil, .goal),
    ]
    let shooting = match.stats(.team1).shooting
    #expect(shooting.shots == 8)
    #expect(shooting.scored == 3)
    #expect(shooting.missed == 5)
    #expect(shooting[.wide] == 2)
    #expect(shooting[.droppedShort] == 1)
    #expect(shooting.accuracy == 3.0 / 8.0)
    #expect(match.stats(.team1).score == match.score(.team1))
}

@Test func noShotsMeansNoAccuracy() {
    #expect(newMatch().stats(.team1).shooting.accuracy == nil)
    #expect(newMatch().stats(.team1).players.isEmpty)
}

@Test func playersAreGroupedAndRankedByScore() {
    var match = newMatch()
    let no7 = match.team1.players[6].id, no11 = match.team1.players[10].id, no14 = match.team1.players[13].id
    match.events = [
        shot(.team1, no11, .point), shot(.team1, no7, .goal), shot(.team1, no11, .point),
        shot(.team1, no14, .point), shot(.team1, no14, .point), shot(.team1, no14, .wide),
        shot(.team1, nil, .point), shot(.team1, nil, .goal),
        shot(.team1, match.team1.players[2].id, .wide),
    ]
    let players = match.stats(.team1).players
    // No.7 (3 points), then No.11 and No.14 (2 each, by jersey), then No.3 (0); shots without a player come last.
    #expect(players.map(\.player) == [no7, no11, no14, match.team1.players[2].id, nil])
    #expect(players[2].shooting.shots == 3)
    #expect(players[2].shooting.accuracy == 2.0 / 3.0)
    #expect(players.last?.score == Score(goals: 1, points: 1))

    let scorers = match.stats(.team1).scorers
    #expect(scorers.map(\.player) == [no7, no11, no14, nil])
}

@Test func scoresAreBrokenDownByShotType() {
    var match = newMatch()
    let no14 = match.team1.players[13].id
    match.events = [
        shot(.team1, no14, .point, .free), shot(.team1, no14, .point, .free), shot(.team1, no14, .wide, .free),
        shot(.team1, no14, .goal, .penalty), shot(.team1, no14, .twoPointer, .free),
        shot(.team1, no14, .point, .fromPlay), shot(.team1, no14, .point, .fortyFive),
    ]
    let player = match.stats(.team1).players[0]
    #expect(player.score == Score(goals: 1, points: 6, twoPointers: 1))
    #expect(player.scoreByShotType[.free] == Score(points: 4, twoPointers: 1))
    #expect(player.scoreByShotType[.penalty] == Score(goals: 1))
    #expect(player.scoreByShotType[.fortyFive] == Score(points: 1))
    #expect(player.scoreByShotType[.sideline] == nil)
}

@Test func foulsCardsAndSubstitutionsAreCounted() {
    var match = newMatch()
    let a = match.team1.players[0].id, b = match.team1.players[1].id
    let events: [MatchEvent.Kind] = [
        .foul(side: .team1, player: a, outcome: .free, card: .yellow),
        .foul(side: .team1, player: a, outcome: .free, card: nil),
        .foul(side: .team1, player: b, outcome: .penalty, card: .black),
        .card(side: .team1, player: a, card: .yellow),
        .card(side: .team2, player: nil, card: .red),
        .substitution(side: .team1, off: a, on: b),
        .kickout(side: .team1, player: nil, won: true),
    ]
    match.events = events.map { MatchEvent(period: .secondHalf, time: 0, kind: $0) }
    let stats = match.stats(.team1)
    #expect(stats.fouls == 3)
    #expect(stats.cards == [.yellow: 2, .black: 1])
    #expect(stats.substitutions == 1)
    #expect(match.stats(.team2).cards == [.red: 1])
}

@Test func statsCanCoverOnePeriod() {
    var match = newMatch()
    match.events = [shot(.team1, nil, .goal, .fromPlay, .firstHalf), shot(.team1, nil, .point, .fromPlay, .secondHalf)]
    let secondHalf = TeamStats(of: .team1, in: match.events.filter { $0.period == .secondHalf })
    #expect(secondHalf.score == Score(points: 1))
    #expect(secondHalf.shooting.shots == 1)
}

@Test func onlyGoalsPointsAndTwoPointersScore() {
    #expect(ShotOutcome.allCases.filter(\.scores) == [.goal, .point, .twoPointer])
}
