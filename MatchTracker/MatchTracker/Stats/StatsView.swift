import MatchCore
import SwiftUI

/// The match's statistics, the two teams side by side, for the whole match or
/// one period. Opened from the match screen's toolbar; it follows the match
/// live, so scores recorded meanwhile appear.
struct StatsView: View {
    let session: MatchSession

    /// `nil` for the whole match.
    @State private var period: MatchPeriod?

    private var match: Match { session.match }

    var body: some View {
        let table = StatsTable(match: match, period: period)
        List {
            if match.playedPeriods.count > 1 {
                Picker("Period", selection: $period) {
                    Text("Match").tag(MatchPeriod?.none)
                    ForEach(match.playedPeriods, id: \.self) { period in
                        Text(shortName(period)).tag(Optional(period))
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                teamsHeader
                ForEach(table.sections) { section in
                    sectionRows(section)
                }
            }

            scorersSection(match.team1, table.team1Scorers)
            scorersSection(match.team2, table.team2Scorers)
        }
        .listSectionSpacing(.compact)
        .environment(\.defaultMinListRowHeight, 32)
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Both teams' names over their columns.
    private var teamsHeader: some View {
        HStack(alignment: .top) {
            teamName(match.team1, alignment: .leading)
            Spacer(minLength: 16)
            teamName(match.team2, alignment: .trailing)
        }
        .font(.headline)
        .accessibilityElement(children: .combine)
    }

    private func teamName(_ team: Team, alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 6) {
            if alignment == .leading, let colors = team.colors { TeamColorBadge(colors: colors, size: 16) }
            Text(EventText.teamName(team))
                .lineLimit(2)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if alignment == .trailing, let colors = team.colors { TeamColorBadge(colors: colors, size: 16) }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    @ViewBuilder
    private func sectionRows(_ section: StatsTable.Section) -> some View {
        Text(section.title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .listRowSeparator(.hidden, edges: .bottom)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
        ForEach(section.rows) { row in
            HStack {
                Text(row.team1)
                    .frame(minWidth: 70, alignment: .leading)
                Text(row.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Text(row.team2)
                    .frame(minWidth: 70, alignment: .trailing)
            }
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(row.label): \(EventText.teamName(match.team1)) \(row.team1), \(EventText.teamName(match.team2)) \(row.team2)")
        }
    }

    @ViewBuilder
    private func scorersSection(_ team: Team, _ scorers: [StatsTable.Scorer]) -> some View {
        Section("\(EventText.teamName(team)) Shooters") {
            if scorers.isEmpty {
                Text("No shots yet")
                    .foregroundStyle(.secondary)
            }
            ForEach(scorers) { scorer in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scorer.name)
                        Text(scorer.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(scorer.score)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// "1st", "2nd", "ET 1st", "ET 2nd", to fit a segmented control.
    private func shortName(_ period: MatchPeriod) -> String {
        switch period {
        case .firstHalf: "1st"
        case .secondHalf: "2nd"
        case .extraTimeFirstHalf: "ET 1st"
        case .extraTimeSecondHalf: "ET 2nd"
        default: period.displayName
        }
    }
}

#if DEBUG
#Preview("Stats, 2nd half") {
    NavigationStack { StatsView(session: .preview(.secondHalf)) }
        .matchScreenAppearance()
}

#Preview("Stats, after extra time") {
    NavigationStack { StatsView(session: .preview(.fullTimeAfterExtraTime)) }
        .matchScreenAppearance()
}

#Preview("Stats, not started") {
    NavigationStack { StatsView(session: .preview(.notStarted)) }
        .matchScreenAppearance()
}
#endif
