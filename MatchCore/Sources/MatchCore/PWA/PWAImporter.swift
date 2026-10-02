import Foundation

/// What a PWA import produced. Nothing is written anywhere; the caller saves it.
public struct PWAImportResult: Sendable {
    public var matches: [Match]
    public var panels: [PlayerPanel]
    /// PWA ids of matches skipped because they were imported before.
    public var skippedMatchIDs: [String]
    /// PWA ids of panels skipped because they were imported before.
    public var skippedPanelIDs: [String]
    /// Things the import could not carry over exactly, worded for the user.
    public var warnings: [String]
}

public enum PWAImportError: Error, Equatable, Sendable {
    case unknownTeam(matchID: String, eventID: String)
    case unknownPlayer(matchID: String, eventID: String, playerID: String)
    case missingField(matchID: String, eventID: String, field: String)
    /// A period-end event whose period is not one the PWA ends into.
    case unexpectedPeriodEnd(matchID: String, eventID: String, period: MatchPeriod)
    case invalidDate(matchID: String, value: String)
}

/// The one-time conversion of the owner's PWA backup into the native model.
/// Every PWA quirk is undone here: string team and player ids become sides and
/// typed ids, `No.N` names become `nil`, and a period-end event records the
/// period that ended instead of the one entered.
public enum PWAImporter {
    /// - Parameters:
    ///   - existingMatchIDs: PWA ids (`legacyID`) of matches already imported; those are skipped.
    ///   - existingPanels: PWA id -> native id of panels already imported; those are skipped,
    ///     and teams that last used them still point at them.
    ///   - timeZone: The zone the PWA's dates were entered in.
    public static func convert(
        _ backup: PWABackup,
        existingMatchIDs: Set<String> = [],
        existingPanels: [String: PanelID] = [:],
        timeZone: TimeZone = .current
    ) throws -> PWAImportResult {
        var result = PWAImportResult(matches: [], panels: [], skippedMatchIDs: [], skippedPanelIDs: [], warnings: [])

        var panelIDs = existingPanels
        for pwaPanel in backup.playerPanels {
            if existingPanels[pwaPanel.id] != nil {
                result.skippedPanelIDs.append(pwaPanel.id)
                continue
            }
            let (panel, dropped) = convert(pwaPanel)
            panelIDs[pwaPanel.id] = panel.id
            result.panels.append(panel)
            if !dropped.isEmpty {
                result.warnings.append("Panel \"\(pwaPanel.name)\" has more than \(PlayerPanel.size) players; not imported: \(dropped.joined(separator: ", ")).")
            }
        }

        for pwaMatch in backup.matches {
            if existingMatchIDs.contains(pwaMatch.id) {
                result.skippedMatchIDs.append(pwaMatch.id)
                continue
            }
            var match = try convert(pwaMatch, timeZone: timeZone, warnings: &result.warnings)
            for side in TeamSide.allCases {
                if let pwaPanelID = backup.lastSelectedPanels["\(pwaMatch.id)-\(side.rawValue)"] {
                    match[side].lastPanelID = panelIDs[pwaPanelID]
                }
            }
            result.matches.append(match)
        }
        return result
    }

    // MARK: - Matches

    static func convert(_ pwa: PWAMatch, timeZone: TimeZone, warnings: inout [String]) throws -> Match {
        var playerIDs: [String: PlayerID] = [:]
        func convertTeam(_ team: PWATeam) -> Team {
            Team(name: team.name, players: team.players.map { pwaPlayer in
                let player = Player(jerseyNumber: pwaPlayer.jerseyNumber, name: realName(pwaPlayer))
                playerIDs[pwaPlayer.id] = player.id
                return player
            })
        }
        let team1 = convertTeam(pwa.team1)
        let team2 = convertTeam(pwa.team2)
        let sides = [pwa.team1.id: TeamSide.team1, pwa.team2.id: TeamSide.team2]

        // "Match Over" ends extra time only if the match went to extra time;
        // after Full Time it marks the end of a match whose last half has already ended.
        let wentToExtraTime = pwa.events.contains {
            ([.extraTimeFirstHalf, .extraTimeHalfTime, .extraTimeSecondHalf] as [MatchPeriod]).contains($0.period)
        }

        var events: [MatchEvent] = []
        for pwaEvent in pwa.events {
            let context = EventContext(matchID: pwa.id, event: pwaEvent, sides: sides, playerIDs: playerIDs)
            if pwaEvent.type == .periodEnd {
                guard let ended = endedPeriod(entering: pwaEvent.period, wentToExtraTime: wentToExtraTime) else {
                    if pwaEvent.period == .matchOver {
                        warnings.append("\(title(pwa)): dropped a \"Match Over\" marker that followed Full Time; the match's last half already ended there.")
                        continue
                    }
                    throw PWAImportError.unexpectedPeriodEnd(matchID: pwa.id, eventID: context.eventID, period: pwaEvent.period)
                }
                events.append(MatchEvent(period: ended, time: pwaEvent.timeElapsed, note: note(pwaEvent), kind: .periodEnd))
            } else {
                events.append(MatchEvent(period: pwaEvent.period, time: pwaEvent.timeElapsed, note: note(pwaEvent), kind: try kind(context)))
            }
        }

        // The PWA's running time is now - periodStartTimestamp; a paused clock keeps it in elapsedTime.
        var clock = MatchClock(period: pwa.currentPeriod, bankedSeconds: pwa.elapsedTime)
        if !pwa.isPaused, let start = pwa.periodStartTimestamp {
            clock.bankedSeconds = 0
            clock.runningSince = Date(timeIntervalSince1970: Double(start) / 1000)
        }

        return Match(
            legacyID: pwa.id,
            matchType: pwa.matchType,
            competition: pwa.competition,
            date: try date(of: pwa, timeZone: timeZone),
            venue: pwa.venue,
            referee: pwa.referee,
            halfLength: pwa.halfLength,
            extraHalfLength: pwa.extraHalfLength,
            team1: team1,
            team2: team2,
            events: events,
            clock: clock,
            liveShareID: pwa.shareId
        )
    }

    /// The PWA stores an unnamed player as `No.<jersey number>`.
    static func realName(_ player: PWAPlayer) -> String? {
        player.name == "No.\(player.jerseyNumber)" ? nil : player.name
    }

    /// The PWA records the period being entered; the native model records the one that ended.
    static func endedPeriod(entering period: MatchPeriod, wentToExtraTime: Bool) -> MatchPeriod? {
        switch period {
        case .halfTime: .firstHalf
        case .fullTime: .secondHalf
        case .extraTimeHalfTime: .extraTimeFirstHalf
        case .matchOver: wentToExtraTime ? .extraTimeSecondHalf : nil
        default: nil
        }
    }

    private static func note(_ event: PWAEvent) -> String? {
        guard let text = event.noteText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private struct EventContext {
        let matchID: String
        let event: PWAEvent
        let sides: [String: TeamSide]
        let playerIDs: [String: PlayerID]

        var eventID: String {
            switch event.id {
            case .string(let string): string
            case .number(let number): String(number)
            }
        }

        func side() throws -> TeamSide {
            guard let teamID = event.teamId, let side = sides[teamID] else {
                throw PWAImportError.unknownTeam(matchID: matchID, eventID: eventID)
            }
            return side
        }

        func optionalSide() throws -> TeamSide? {
            event.teamId == nil ? nil : try side()
        }

        func player(_ pwaID: String?) throws -> PlayerID? {
            guard let pwaID else { return nil }
            guard let id = playerIDs[pwaID] else {
                throw PWAImportError.unknownPlayer(matchID: matchID, eventID: eventID, playerID: pwaID)
            }
            return id
        }

        func required<T>(_ value: T?, _ field: String) throws -> T {
            guard let value else {
                throw PWAImportError.missingField(matchID: matchID, eventID: eventID, field: field)
            }
            return value
        }
    }

    private static func kind(_ c: EventContext) throws -> MatchEvent.Kind {
        let e = c.event
        switch e.type {
        case .shot:
            return .shot(side: try c.side(), player: try c.player(e.player1Id),
                         outcome: try c.required(e.shotOutcome, "shotOutcome"), type: try c.required(e.shotType, "shotType"))
        case .foulConceded:
            return .foul(side: try c.side(), player: try c.player(e.player1Id),
                         outcome: try c.required(e.foulOutcome, "foulOutcome"), card: e.cardType)
        case .card:
            return .card(side: try c.side(), player: try c.player(e.player1Id), card: try c.required(e.cardType, "cardType"))
        case .kickout:
            return .kickout(side: try c.side(), player: try c.player(e.player1Id), won: try c.required(e.wonKickout, "wonKickout"))
        case .substitution:
            return .substitution(side: try c.side(), off: try c.player(e.player1Id), on: try c.player(e.player2Id))
        case .note:
            return .note(side: try c.optionalSide())
        case .periodEnd:
            return .periodEnd
        }
    }

    /// The PWA's date field is "YYYY-MM-DD" with no time; it becomes midday in
    /// `timeZone`, so the day stays the same when viewed a few hours either side.
    /// A missing or malformed date falls back to when the match was created, which
    /// the PWA's ids start with ("1754435709770-961121" is epoch milliseconds).
    static func date(of match: PWAMatch, timeZone: TimeZone) throws -> Date {
        let parts = match.dateTime.split(separator: "-").compactMap { Int($0) }
        if parts.count == 3 {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)
            if components.isValidDate(in: calendar), let date = calendar.date(from: components) {
                return date
            }
        }
        if let prefix = match.id.split(separator: "-").first, let millis = Int64(prefix) {
            return Date(timeIntervalSince1970: Double(millis) / 1000)
        }
        throw PWAImportError.invalidDate(matchID: match.id, value: match.dateTime)
    }

    private static func title(_ match: PWAMatch) -> String {
        "\(match.team1.name) v \(match.team2.name) (\(match.dateTime))"
    }

    // MARK: - Panels

    /// Places players into 30 slots the way the PWA's `normalizePanel` does:
    /// valid unclaimed jersey numbers first, then any other named player into the
    /// first free slot; a legacy panel with no numbers fills 1..N in stored order.
    /// Returns the names that did not fit.
    static func convert(_ pwa: PWAPanel) -> (PlayerPanel, dropped: [String]) {
        var slots: [String?] = Array(repeating: nil, count: PlayerPanel.size)
        var filled = Array(repeating: false, count: PlayerPanel.size)
        var dropped: [String] = []
        let validRange = 1...PlayerPanel.size

        if pwa.players.contains(where: { $0.jerseyNumber != nil }) {
            var placed = Set<Int>()
            for (index, player) in pwa.players.enumerated() {
                if let n = player.jerseyNumber, validRange.contains(n), !filled[n - 1] {
                    slots[n - 1] = player.name
                    filled[n - 1] = true
                    placed.insert(index)
                }
            }
            for (index, player) in pwa.players.enumerated() where !placed.contains(index) {
                guard Player.cleaned(player.name) != nil else { continue }
                if let free = filled.firstIndex(of: false) {
                    slots[free] = player.name
                    filled[free] = true
                } else {
                    dropped.append(player.name.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } else {
            for (index, player) in pwa.players.enumerated() {
                if index < PlayerPanel.size {
                    slots[index] = player.name
                } else if Player.cleaned(player.name) != nil {
                    dropped.append(player.name.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        let panel = PlayerPanel(
            legacyID: pwa.id,
            name: pwa.name,
            createdAt: pwa.createdDate.flatMap(parseISODate),
            slots: slots.enumerated().map { PanelSlot(jerseyNumber: $0.offset + 1, name: $0.element) }
        )
        return (panel, dropped)
    }

    private static func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
