import Foundation

extension Team {
    /// This team's players with `panel`'s names copied in by jersey number:
    /// each player keeps their id (events refer to them) and takes the name in
    /// their slot, an empty slot clearing it. Players 31 to 40 are added or
    /// left out so the team has as many players as the panel has slots.
    public func players(importing panel: PlayerPanel) -> [Player] {
        panel.slots.enumerated().map { index, slot in
            if index < players.count {
                Player(id: players[index].id, jerseyNumber: players[index].jerseyNumber, name: slot.name)
            } else {
                Player(jerseyNumber: slot.jerseyNumber, name: slot.name)
            }
        }
    }
}

extension Match {
    /// Whether a panel can be imported into a team: only before throw-in.
    public var canImportPanel: Bool { clock.period == .notStarted }

    /// Imports `panel` into `side` (see `Team.players(importing:)`) and
    /// remembers it as the team's last panel. Returns `false`, changing
    /// nothing, after throw-in or if the panel's slots aren't numbered 1 to n.
    @discardableResult
    public mutating func importPanel(_ panel: PlayerPanel, into side: TeamSide) -> Bool {
        updateRoster(side, players: self[side].players(importing: panel), fromPanel: panel.id)
    }

    /// `updateRoster(_:players:)` for a team sheet edited after importing the
    /// panel `panelID`, which is remembered as the team's last panel. Returns
    /// `false`, changing nothing, if the roster isn't valid or, with a panel,
    /// after throw-in.
    @discardableResult
    public mutating func updateRoster(_ side: TeamSide, players: [Player], fromPanel panelID: PanelID?) -> Bool {
        guard let panelID else { return updateRoster(side, players: players) }
        guard canImportPanel else { return false }
        var changed = self
        guard changed.updateRoster(side, players: players) else { return false }
        changed[side].lastPanelID = panelID
        self = changed
        return true
    }
}
