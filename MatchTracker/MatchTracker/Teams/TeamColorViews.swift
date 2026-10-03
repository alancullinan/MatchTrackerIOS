import MatchCore
import SwiftUI

extension KitColor {
    /// How the colour looks. Strong, saturated shades, so they read in sunlight.
    var color: Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// The shade as red, green and blue from 0 to 1 (also handed to the Live Activity).
    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .white: (1, 1, 1)
        case .black: (0.11, 0.11, 0.12)
        case .red: (0.82, 0.13, 0.18)
        case .maroon: (0.48, 0.12, 0.24)
        case .green: (0.12, 0.55, 0.23)
        case .gold: (0.95, 0.72, 0.02)
        case .orange: (0.95, 0.55, 0)
        case .primrose: (0.96, 0.89, 0.48)
        case .blue: (0.12, 0.31, 0.75)
        case .skyBlue: (0.42, 0.71, 0.93)
        case .navy: (0.11, 0.16, 0.29)
        case .purple: (0.42, 0.17, 0.57)
        }
    }
}

extension TeamColors {
    /// "Black and Gold", or "Green".
    var displayName: String {
        guard let secondary else { return primary.displayName }
        return "\(primary.displayName) and \(secondary.displayName)"
    }
}

/// A small round badge in a team's colours: split down the middle for two colours.
struct TeamColorBadge: View {
    let colors: TeamColors
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            colors.primary.color
            (colors.secondary ?? colors.primary).color
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        // Keeps white and pale colours visible on a light background, and dark ones on dark.
        .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
        .accessibilityLabel(colors.displayName)
    }
}

/// Picks a team's main colour and an optional second colour from the palette.
/// Tapping the selected colour again leaves it selected; "No Colours" clears them.
struct TeamColorsPicker: View {
    let teamName: String
    @Binding var colors: TeamColors?

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    var body: some View {
        Form {
            Section("Main Colour") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(KitColor.allCases, id: \.self) { kit in
                        swatch(kit, isSelected: colors?.primary == kit) {
                            colors = TeamColors(kit, colors?.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    noneSwatch(isSelected: colors != nil && colors?.secondary == nil) {
                        if let primary = colors?.primary { colors = TeamColors(primary) }
                    }
                    ForEach(KitColor.allCases, id: \.self) { kit in
                        swatch(kit, isSelected: colors?.secondary == kit) {
                            if let primary = colors?.primary { colors = TeamColors(primary, kit) }
                        }
                        .disabled(colors == nil || colors?.primary == kit)
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("Second Colour")
            } footer: {
                if colors == nil { Text("Choose a main colour first.") }
            }

            if colors != nil {
                Section {
                    Button("No Colours", role: .destructive) { colors = nil }
                }
            }
        }
        .navigationTitle(teamName.isEmpty ? "Team Colours" : "\(teamName) Colours")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: colors)
    }

    private func swatch(_ kit: KitColor, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(kit.color)
                .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.title3.bold())
                            .foregroundStyle(kit.prefersDarkCheckmark ? .black : .white)
                    }
                }
                .frame(width: 48, height: 48)
                .padding(2)
                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kit.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func noneSwatch(isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .overlay {
                    Text("None").font(.caption2.bold()).foregroundStyle(.secondary)
                }
                .frame(width: 48, height: 48)
                .padding(2)
                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .disabled(colors == nil)
        .accessibilityLabel("No second colour")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension KitColor {
    /// Pale colours need a dark checkmark to be seen.
    var prefersDarkCheckmark: Bool {
        switch self {
        case .white, .gold, .orange, .primrose, .skyBlue: true
        default: false
        }
    }
}

#if DEBUG
#Preview("Picker") {
    @Previewable @State var colors: TeamColors? = TeamColors(.black, .gold)
    NavigationStack {
        TeamColorsPicker(teamName: "Kilkenny", colors: $colors)
    }
}

#Preview("Picker, nothing chosen") {
    @Previewable @State var colors: TeamColors?
    NavigationStack {
        TeamColorsPicker(teamName: "Cuala", colors: $colors)
    }
}
#endif
