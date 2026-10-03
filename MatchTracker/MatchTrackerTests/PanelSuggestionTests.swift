import Foundation
import MatchCore
import Testing
@testable import MatchTracker

@MainActor
struct PanelSuggestionTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    let seniors = PanelID()
    let juniors = PanelID()

    private func day(_ n: Double) -> Date { t0.addingTimeInterval(n * 86_400) }

    private func team(_ name: String, last: PanelID? = nil) -> Team {
        var team = Team.roster(name: name)
        team.lastPanelID = last
        return team
    }

    @Test func theTeamsOwnLastPanelComesFirst() {
        let past = [PanelSuggestion.PastTeam(date: day(5), name: "Na Fianna", lastPanelID: juniors)]
        let id = PanelSuggestion.suggested(for: team("Na Fianna", last: seniors), pastTeams: past, panels: [seniors, juniors])
        #expect(id == seniors)
    }

    @Test func otherwiseTheSameTeamsMostRecentPanelIsSuggested() {
        let past = [
            PanelSuggestion.PastTeam(date: day(1), name: "Na Fianna", lastPanelID: juniors),
            PanelSuggestion.PastTeam(date: day(3), name: "na fianna ", lastPanelID: seniors),
            PanelSuggestion.PastTeam(date: day(4), name: "Cuala", lastPanelID: juniors),
            PanelSuggestion.PastTeam(date: day(5), name: "Na Fianna", lastPanelID: nil),
        ]
        let id = PanelSuggestion.suggested(for: team("Na Fianna"), pastTeams: past, panels: [seniors, juniors])
        #expect(id == seniors)
    }

    @Test func aDeletedPanelIsNeverSuggested() {
        let past = [
            PanelSuggestion.PastTeam(date: day(3), name: "Na Fianna", lastPanelID: seniors),
            PanelSuggestion.PastTeam(date: day(1), name: "Na Fianna", lastPanelID: juniors),
        ]
        let id = PanelSuggestion.suggested(for: team("Na Fianna", last: seniors), pastTeams: past, panels: [juniors])
        #expect(id == juniors)
    }

    @Test func noPanelIsSuggestedForATeamNeverGivenOne() {
        let past = [PanelSuggestion.PastTeam(date: day(1), name: "Cuala", lastPanelID: seniors)]
        #expect(PanelSuggestion.suggested(for: team("Na Fianna"), pastTeams: past, panels: [seniors]) == nil)
    }

    @Test func namesMatchIgnoringCaseAndAccents() {
        #expect(PanelSuggestion.sameName("Seán Mac Cumhaills", "sean mac cumhaills"))
        #expect(!PanelSuggestion.sameName("Na Fianna", "Fianna"))
    }
}
