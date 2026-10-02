public struct Team: Hashable, Sendable, Codable {
    /// Players per team; jersey numbers run 1 to `rosterSize`.
    public static let rosterSize = 30

    public var name: String
    public var players: [Player]
    /// `nil` until colours are chosen for the team.
    public var colors: TeamColors?
    /// Whether recording a score for this team opens the scorer sheet. On by
    /// default; switched off for a team whose players aren't known.
    public var asksForScorers: Bool
    /// The panel last imported into this team, offered first next time.
    public var lastPanelID: PanelID?

    public init(
        name: String,
        players: [Player],
        colors: TeamColors? = nil,
        asksForScorers: Bool = true,
        lastPanelID: PanelID? = nil
    ) {
        self.name = name
        self.players = players
        self.colors = colors
        self.asksForScorers = asksForScorers
        self.lastPanelID = lastPanelID
    }

    /// A team of `rosterSize` unnamed players, numbered from 1.
    public static func roster(name: String) -> Team {
        Team(name: name, players: (1...rosterSize).map { Player(jerseyNumber: $0) })
    }

    public func player(_ id: PlayerID) -> Player? {
        players.first { $0.id == id }
    }

    public func player(jersey: Int) -> Player? {
        players.first { $0.jerseyNumber == jersey }
    }
}
