import Foundation
import Testing
@testable import MatchCore

private func event(_ period: MatchPeriod, _ time: Int, _ kind: MatchEvent.Kind = .note(side: nil)) -> MatchEvent {
    MatchEvent(period: period, time: time, kind: kind)
}

private func shot(_ side: TeamSide, _ outcome: ShotOutcome, _ period: MatchPeriod, _ time: Int) -> MatchEvent {
    event(period, time, .shot(side: side, player: nil, outcome: outcome, type: .fromPlay))
}

private func match(_ events: [MatchEvent]) -> Match {
    var match = Match.new(matchType: .football, team1Name: "A", team2Name: "B", date: Date(timeIntervalSince1970: 0))
    match.events = events
    return match
}

@Test func eventsSortByPeriodThenTime() {
    let a = event(.secondHalf, 10), b = event(.firstHalf, 900), c = event(.firstHalf, 5), d = event(.extraTimeFirstHalf, 1)
    let ordered = match([a, b, c, d]).eventsInOrder
    #expect(ordered.map(\.id) == [c.id, b.id, a.id, d.id])
    #expect(match([a, b, c, d]).eventsNewestFirst.map(\.id) == [d.id, a.id, b.id, c.id])
}

@Test func aPeriodEndIsLastInItsPeriod() {
    let end = event(.secondHalf, 2138, .periodEnd)
    let late = event(.secondHalf, 2191)
    let next = event(.extraTimeFirstHalf, 0)
    let early = event(.secondHalf, 100)
    #expect(match([end, next, late, early]).eventsInOrder.map(\.id) == [early.id, late.id, end.id, next.id])
}

@Test func eventsAtTheSameMomentKeepRecordedOrder() {
    let first = event(.firstHalf, 60), second = event(.firstHalf, 60), third = event(.firstHalf, 60)
    #expect(match([first, second, third]).eventsInOrder.map(\.id) == [first.id, second.id, third.id])
}

@Test func editingAnEventsTimeMovesIt() {
    let a = event(.firstHalf, 100), b = event(.firstHalf, 200)
    var m = match([a, b])
    m.events[1].time = 50
    #expect(m.eventsInOrder.map(\.id) == [b.id, a.id])
    m.events[1].period = .secondHalf
    #expect(m.eventsInOrder.map(\.id) == [a.id, b.id])
}

@Test func scoreThroughAnEventCountsOnlyWhatCameBefore() {
    let goal = shot(.team1, .goal, .firstHalf, 300)
    let halfTime = event(.firstHalf, 1900, .periodEnd)
    let point = shot(.team1, .point, .secondHalf, 60)
    let twoPointer = shot(.team2, .twoPointer, .firstHalf, 1000)
    // Recorded out of order: the score follows match time, not recording order.
    let m = match([point, goal, halfTime, twoPointer])

    #expect(m.score(.team1, through: goal.id) == Score(goals: 1))
    #expect(m.score(.team2, through: goal.id) == Score())
    #expect(m.score(.team1, through: halfTime.id) == Score(goals: 1))
    #expect(m.score(.team2, through: halfTime.id) == Score(points: 2, twoPointers: 1))
    #expect(m.score(.team1, through: point.id) == Score(goals: 1, points: 1))
    #expect(m.score(.team1, through: EventID()) == nil)
}
