import Foundation
import Testing
@testable import MatchCore

private let t0 = Date(timeIntervalSince1970: 1_754_800_000)

private func playing() -> Match {
    var match = Match.new(matchType: .football, team1Name: "Team A", team2Name: "Team B", date: t0)
    match.start(at: t0)
    return match
}

// #expect can't call a mutating method itself, so each step's result is kept first.

// MARK: - Fouls

@Test func aFoulsCardAndPlayerCanBeFilledIn() throws {
    var match = playing()
    let recorded = match.record(.foul(side: .team2, player: nil, outcome: .free, card: nil), at: t0.addingTimeInterval(300))
    let foul = try #require(recorded)
    let fouler = match.team2.players[5].id

    let updated = match.updateFoul(foul.id, outcome: .penalty, card: .black, player: fouler, note: " cynical ")
    #expect(updated)
    let after = try #require(match.event(foul.id))
    #expect(after.kind == .foul(side: .team2, player: fouler, outcome: .penalty, card: .black))
    #expect(after.note == "cynical")
    #expect(after.time == 300)
}

@Test func aFoulCantBeGivenAPlayerFromTheOtherTeam() throws {
    var match = playing()
    let recorded = match.record(.foul(side: .team1, player: nil, outcome: .free, card: nil), at: t0)
    let foul = try #require(recorded)

    let updated = match.updateFoul(foul.id, outcome: .free, card: .yellow, player: match.team2.players[0].id, note: nil)
    #expect(!updated)
    #expect(match.event(foul.id) == foul)
}

@Test func aFoulsCardCanBeTakenAway() throws {
    var match = playing()
    let recorded = match.record(.foul(side: .team1, player: nil, outcome: .free, card: .yellow), at: t0)
    let foul = try #require(recorded)

    let updated = match.updateFoul(foul.id, outcome: .free, card: nil, player: nil, note: nil)
    #expect(updated)
    #expect(match.event(foul.id)?.kind == .foul(side: .team1, player: nil, outcome: .free, card: nil))
}

@Test func onlyAFoulCanBeUpdatedAsAFoul() throws {
    var match = playing()
    let recorded = match.record(.kickout(side: .team1, player: nil, won: true), at: t0)
    let kickout = try #require(recorded)

    let updated = match.updateFoul(kickout.id, outcome: .free, card: nil, player: nil, note: nil)
    #expect(!updated)
}

@Test func cardsAreOfferedYellowBlackRed() {
    #expect(CardType.offered == [.yellow, .black, .red])
    #expect(Set(CardType.offered) == Set(CardType.allCases))
}

// MARK: - Kickouts

@Test func aKickoutCanBeChangedToLostAndGivenAPlayer() throws {
    var match = playing()
    let recorded = match.record(.kickout(side: .team1, player: nil, won: true), at: t0.addingTimeInterval(90))
    let kickout = try #require(recorded)
    let catcher = match.team1.players[7].id

    let updated = match.updateKickout(kickout.id, won: false, player: catcher, note: "")
    #expect(updated)
    let after = try #require(match.event(kickout.id))
    #expect(after.kind == .kickout(side: .team1, player: catcher, won: false))
    #expect(after.note == nil)
}

// MARK: - Substitutions

@Test func aSubstitutionsPlayersCanBeFilledIn() throws {
    var match = playing()
    let recorded = match.record(.substitution(side: .team1, off: nil, on: nil), at: t0.addingTimeInterval(1200))
    let sub = try #require(recorded)
    let off = match.team1.players[10].id
    let on = match.team1.players[17].id

    let updated = match.updateSubstitution(sub.id, off: off, on: on, note: "blood sub")
    #expect(updated)
    let after = try #require(match.event(sub.id))
    #expect(after.kind == .substitution(side: .team1, off: off, on: on))
    #expect(after.note == "blood sub")
}

@Test func aPlayerCantReplaceThemselves() throws {
    var match = playing()
    let recorded = match.record(.substitution(side: .team1, off: nil, on: nil), at: t0)
    let sub = try #require(recorded)
    let player = match.team1.players[10].id

    let updated = match.updateSubstitution(sub.id, off: player, on: player, note: nil)
    #expect(!updated)
}

@Test func aSubstitutionCanNameOnlyOneOfThePlayers() throws {
    var match = playing()
    let recorded = match.record(.substitution(side: .team2, off: nil, on: nil), at: t0)
    let sub = try #require(recorded)
    let on = match.team2.players[20].id

    let updated = match.updateSubstitution(sub.id, off: nil, on: on, note: nil)
    #expect(updated)
    #expect(match.event(sub.id)?.kind == .substitution(side: .team2, off: nil, on: on))
}

@Test func aSubstitutionCantBringOnAPlayerFromTheOtherTeam() throws {
    var match = playing()
    let recorded = match.record(.substitution(side: .team1, off: nil, on: nil), at: t0)
    let sub = try #require(recorded)

    let updated = match.updateSubstitution(sub.id, off: nil, on: match.team2.players[20].id, note: nil)
    #expect(!updated)
}

// MARK: - Notes

@Test func aNotesTextIsTrimmed() throws {
    var match = playing()
    let recorded = match.record(.note(side: nil), at: t0)
    let note = try #require(recorded)

    let updated = match.updateNote(note.id, text: "  Rain starting \n")
    #expect(updated)
    #expect(match.event(note.id)?.note == "Rain starting")
}

@Test func aNoteCantBeMadeBlank() throws {
    var match = playing()
    let recorded = match.record(.note(side: .team1), note: "Wind behind", at: t0)
    let note = try #require(recorded)

    let updated = match.updateNote(note.id, text: "   ")
    #expect(!updated)
    #expect(match.event(note.id)?.note == "Wind behind")
}

@Test func onlyANoteCanBeUpdatedAsANote() throws {
    var match = playing()
    let recorded = match.record(.shot(side: .team1, player: nil, outcome: .point, type: .fromPlay), at: t0)
    let shot = try #require(recorded)

    let updated = match.updateNote(shot.id, text: "Lovely score")
    #expect(!updated)
}
