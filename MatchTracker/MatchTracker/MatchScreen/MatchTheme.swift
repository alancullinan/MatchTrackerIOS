import MatchCore
import SwiftUI

/// The match screen's colours, from the agreed glass design. The screen and
/// the sheets it opens are always dark, so each colour has one shade.
enum MatchTheme {
    static let gold = Color(hex: 0xFFD60A)
    static let goldInk = Color(hex: 0x1A1A00)
    static let goal = Color(hex: 0x30D158)
    static let point = Color.white
    static let twoPointer = Color(hex: 0xF08A24)
    static let muted = Color.white.opacity(0.75)
    /// The background when Reduce Transparency is on, and behind the photo while it loads.
    static let pitch = Color(hex: 0x10301C)

    /// A referee's card.
    static func card(_ card: CardType) -> Color {
        switch card {
        case .yellow: Color(hex: 0xF5CB1A)
        case .black: Color(hex: 0x161616)
        case .red: Color(hex: 0xE8382B)
        }
    }

    /// The lettering for the clock, scores and labels: standard SF Pro.
    /// Changing numbers also take `.monospacedDigit()`.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Color {
    /// A colour from hex RGB.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// The match screen's background: a photo of grass under a faint dark green
/// shade, or plain pitch green with Reduce Transparency.
struct GrassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        MatchTheme.pitch
            .overlay {
                if !reduceTransparency {
                    Image("GrassBackground")
                        .resizable()
                        .scaledToFill()
                        .overlay(Color(red: 4 / 255, green: 24 / 255, blue: 10 / 255).opacity(0.30))
                }
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// The flag on the match screen's goal and point buttons: a waving flag on a
/// pole with a knob, drawn in a 24-point square (from the design's SVG).
struct WavingFlag: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        path.addRoundedRect(in: CGRect(origin: point(4.4, 3.5), size: CGSize(width: 2.2 * scale, height: 18.6 * scale)),
                            cornerSize: CGSize(width: 1.1 * scale, height: 1.1 * scale))
        path.addEllipse(in: CGRect(origin: point(4.2, 1.7), size: CGSize(width: 2.6 * scale, height: 2.6 * scale)))
        path.move(to: point(6.5, 4.8))
        path.addCurve(to: point(12.9, 5.1), control1: point(8.8, 3.4), control2: point(10.9, 4.2))
        path.addCurve(to: point(19, 5), control1: point(14.9, 6), control2: point(16.8, 6.3))
        path.addCurve(to: point(19.7, 5.4), control1: point(19.3, 4.8), control2: point(19.7, 5))
        path.addLine(to: point(19.7, 13.5))
        path.addCurve(to: point(19.3, 14.2), control1: point(19.7, 13.8), control2: point(19.6, 14))
        path.addCurve(to: point(13, 14.3), control1: point(17.1, 15.5), control2: point(15.1, 15.2))
        path.addCurve(to: point(6.5, 14), control1: point(10.9, 13.4), control2: point(8.8, 12.6))
        path.closeSubpath()
        return path
    }
}

/// An umpire's flag for event icons: a pole with a swallow-tailed pennant, drawn in a 32-point square.
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

extension View {
    /// A Liquid Glass panel, or a solid one with Reduce Transparency.
    func matchGlass(in shape: some Shape, interactive: Bool = false) -> some View {
        modifier(MatchGlass(shape: shape, interactive: interactive))
    }
}

private struct MatchGlass<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(hex: 0x1E4A2E), in: shape)
                .overlay(shape.stroke(.white.opacity(0.22), lineWidth: 1))
        } else {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        }
    }
}

extension View {
    /// Dark for a screen pushed onto a stack whose other screens follow the
    /// system setting. (`preferredColorScheme` would turn the whole window dark,
    /// so the match list would flash dark during the push.)
    func matchScreenAppearance() -> some View {
        environment(\.colorScheme, .dark)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Dark for a sheet the match screen opens; it applies to the sheet only.
    func matchSheetAppearance() -> some View {
        preferredColorScheme(.dark)
    }
}
