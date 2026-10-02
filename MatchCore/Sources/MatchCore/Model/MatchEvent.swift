/// Something that happened in a match. The fields every event has live here;
/// what differs by type lives in `kind`, so each type carries only its own data.
public struct MatchEvent: Hashable, Sendable, Codable {
    public var id: EventID
    /// For `.periodEnd`, the period that ended.
    public var period: MatchPeriod
    /// Seconds into `period`.
    public var time: Int
    /// Free text. Any event can carry one, not only `.note`.
    public var note: String?
    public var kind: Kind

    public init(id: EventID = EventID(), period: MatchPeriod, time: Int, note: String? = nil, kind: Kind) {
        self.id = id
        self.period = period
        self.time = time
        self.note = note
        self.kind = kind
    }

    public enum Kind: Hashable, Sendable, Codable {
        case shot(side: TeamSide, player: PlayerID?, outcome: ShotOutcome, type: ShotType)
        /// `side` is the team that conceded the foul.
        case foul(side: TeamSide, player: PlayerID?, outcome: FoulOutcome, card: CardType?)
        /// A card on its own. New cards are recorded with a foul; this is for older records.
        case card(side: TeamSide, player: PlayerID?, card: CardType)
        case kickout(side: TeamSide, player: PlayerID?, won: Bool)
        case substitution(side: TeamSide, off: PlayerID?, on: PlayerID?)
        /// The text is the event's `note`.
        case note(side: TeamSide?)
        case periodEnd
    }

    /// The team the event belongs to; `nil` for period ends and notes without a team.
    public var side: TeamSide? {
        switch kind {
        case .shot(let side, _, _, _), .foul(let side, _, _, _), .card(let side, _, _),
             .kickout(let side, _, _), .substitution(let side, _, _):
            side
        case .note(let side):
            side
        case .periodEnd:
            nil
        }
    }

    public var type: EventType {
        switch kind {
        case .shot: .shot
        case .foul: .foulConceded
        case .card: .card
        case .kickout: .kickout
        case .substitution: .substitution
        case .note: .note
        case .periodEnd: .periodEnd
        }
    }
}
