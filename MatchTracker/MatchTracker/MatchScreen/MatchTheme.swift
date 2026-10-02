import MatchCore
import SwiftUI
import UIKit

/// The match screen's colours, from the agreed design: a calm pitch green with
/// gold for the period and the main button. Each has a light and a dark shade,
/// both chosen to read in sunlight.
enum MatchTheme {
    static let pitch = Color(light: 0xE6EFE5, dark: 0x0D2418)
    static let stripe = Color(light: 0x1E5028, dark: 0xFFFFFF).opacity(0.035)
    static let gold = Color(light: 0xA86F00, dark: 0xF2B631)
    static let goldInk = Color(light: 0xFFF8E6, dark: 0x241A00)
    static let goal = Color(light: 0x23913A, dark: 0x3FB24F)
    static let point = Color.white
    static let twoPointer = Color(light: 0xC9640A, dark: 0xF08A24)
    static let flagDisc = Color(light: 0x10241A, dark: 0x10241A)
    static let muted = Color(light: 0x4C6354, dark: 0xA9BCAE)
    static let live = Color(light: 0xC62A1D, dark: 0xFF6B5E)

    /// A referee's card.
    static func card(_ card: CardType) -> Color {
        switch card {
        case .yellow: Color(light: 0xF2C200, dark: 0xF5CB1A)
        case .black: Color(light: 0x161616, dark: 0x161616)
        case .red: Color(light: 0xD32418, dark: 0xE8382B)
        }
    }

    /// Condensed scoreboard lettering for the clock, scores and labels.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

extension Color {
    /// A colour with its own shade for light and dark mode, from hex RGB.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// The calm pitch background: plain green with faint mowing stripes.
struct PitchBackground: View {
    var body: some View {
        MatchTheme.pitch
            .overlay {
                Canvas { context, size in
                    let stripe: CGFloat = 64
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: stripe)), with: .color(MatchTheme.stripe))
                        y += stripe * 2
                    }
                }
            }
            .ignoresSafeArea()
    }
}

/// An umpire's flag: a pole with a swallow-tailed pennant, drawn in a 32-point square.
struct FlagShape: Shape {
    enum Part { case pole, pennant }
    let part: Part

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 32
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        switch part {
        case .pole:
            path.addRoundedRect(in: CGRect(origin: point(6.8, 4), size: CGSize(width: 2.4 * scale, height: 25 * scale)),
                                cornerSize: CGSize(width: 1.2 * scale, height: 1.2 * scale))
        case .pennant:
            path.move(to: point(9, 5))
            path.addLine(to: point(26, 5))
            path.addLine(to: point(22, 11))
            path.addLine(to: point(26, 17))
            path.addLine(to: point(9, 17))
            path.closeSubpath()
        }
        return path
    }
}

/// A flag with its pennant filled, or outlined for a miss.
struct FlagIcon: View {
    let fill: Color?
    var pole: Color = Color(white: 0.91)

    var body: some View {
        ZStack {
            FlagShape(part: .pole).fill(pole)
            if let fill {
                FlagShape(part: .pennant).fill(fill)
                // Keeps a white pennant visible on a pale background.
                FlagShape(part: .pennant).stroke(pole.opacity(0.35), lineWidth: 1)
            } else {
                FlagShape(part: .pennant).stroke(pole, lineWidth: 1.6)
            }
        }
        .accessibilityHidden(true)
    }
}
