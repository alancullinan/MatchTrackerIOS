import Foundation

/// The colours teams can be given: a fixed palette that covers the county and
/// club colours of the four codes. Stored by case name, like the other enums:
/// add cases, never rename one. How each looks is up to the app.
public enum KitColor: String, Codable, Sendable, CaseIterable {
    case white
    case black
    case red
    case maroon
    case green
    case gold
    case orange
    case primrose
    case blue
    case skyBlue
    case navy
    case purple

    /// The name to show.
    public var displayName: String {
        switch self {
        case .white: "White"
        case .black: "Black"
        case .red: "Red"
        case .maroon: "Maroon"
        case .green: "Green"
        case .gold: "Gold"
        case .orange: "Saffron"
        case .primrose: "Primrose"
        case .blue: "Blue"
        case .skyBlue: "Sky Blue"
        case .navy: "Navy"
        case .purple: "Purple"
        }
    }
}

/// A team's colours: a main colour, and a second one unless the kit has only one.
public struct TeamColors: Hashable, Sendable, Codable {
    public var primary: KitColor
    public var secondary: KitColor?

    /// A second colour the same as the main one is dropped.
    public init(_ primary: KitColor, _ secondary: KitColor? = nil) {
        self.primary = primary
        self.secondary = secondary == primary ? nil : secondary
    }
}
