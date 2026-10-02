/// Which of a match's two teams. Teams are referred to by side, never by an id.
public enum TeamSide: String, Hashable, Sendable, Codable, CaseIterable {
    case team1
    case team2

    public var opponent: TeamSide {
        switch self {
        case .team1: .team2
        case .team2: .team1
        }
    }
}
