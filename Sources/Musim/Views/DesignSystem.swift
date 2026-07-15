import SwiftUI
import AppKit

// MARK: - Adaptive color helper

extension Color {
    init(light: NSColor, dark: NSColor) {
        self = Color(nsColor: NSColor(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
    init(lightHex: UInt, darkHex: UInt) { self.init(light: NSColor(hex: lightHex), dark: NSColor(hex: darkHex)) }
    init(hex: UInt) { self.init(nsColor: NSColor(hex: hex)) }
}

extension NSColor {
    convenience init(hex: UInt) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF)/255, green: CGFloat((hex >> 8) & 0xFF)/255,
                  blue: CGFloat(hex & 0xFF)/255, alpha: 1)
    }
}

// MARK: - Malaysian-inspired accent palette

struct AccentOption: Identifiable {
    let id: String
    let name: String
    let hex: UInt
    let hex2: UInt   // gradient partner
}

enum AccentPalette {
    static let options: [AccentOption] = [
        .init(id: "sunset",   name: "Senja",       hex: 0xF1592A, hex2: 0xE23A2E), // orange → red
        .init(id: "bungaraya",name: "Bunga Raya",  hex: 0xE0243B, hex2: 0xB01029), // hibiscus red
        .init(id: "songket",  name: "Songket",     hex: 0xE0A126, hex2: 0xD4841A), // gold
        .init(id: "tehtarik", name: "Teh Tarik",   hex: 0xC97B3C, hex2: 0xA5602A), // caramel
        .init(id: "rafflesia",name: "Rafflesia",   hex: 0xD84327, hex2: 0xA83218), // deep orange-red
        .init(id: "pandan",   name: "Pandan",      hex: 0x4FA85A, hex2: 0x3B8C46), // green
        .init(id: "laut",     name: "Laut",        hex: 0x2E9AA6, hex2: 0x1F7C86), // teal
    ]
    static func option(_ id: String) -> AccentOption { options.first { $0.id == id } ?? options[0] }
}

// MARK: - Theme (OLED-leaning dark, warm; off-white light). Accent is dynamic.

enum Theme {
    static let bg           = Color(lightHex: 0xF6F5F2, darkHex: 0x0B0B0C)
    static let bgElevated   = Color(lightHex: 0xFFFFFF, darkHex: 0x151518)
    static let surface      = Color(lightHex: 0xFFFFFF, darkHex: 0x1C1C20)
    static let surfaceHover  = Color(lightHex: 0xEEEDEA, darkHex: 0x26262B)
    static let border       = Color(lightHex: 0xE4E3DF, darkHex: 0x2B2B31)
    static let borderStrong = Color(lightHex: 0xD6D5D0, darkHex: 0x3A3A42)

    static var accent: Color { Color(hex: AccentPalette.option(AppSettings.shared.accent).hex) }
    static var accent2: Color { Color(hex: AccentPalette.option(AppSettings.shared.accent).hex2) }
    static var accentSoft: Color { accent.opacity(0.16) }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let textPrimary   = Color(lightHex: 0x1A1A1A, darkHex: 0xF2F1EE)
    static let textSecondary = Color(lightHex: 0x6B6B67, darkHex: 0x9A9A95)

    static let rLg: CGFloat = 16
    static let rMd: CGFloat = 12
    static let rSm: CGFloat = 9

    static let bouncy = Animation.spring(response: 0.36, dampingFraction: 0.8)
    static let smooth = Animation.spring(response: 0.42, dampingFraction: 0.92)
    static let snappy = Animation.spring(response: 0.24, dampingFraction: 0.82)
    static let expressive = Animation.spring(response: 0.44, dampingFraction: 0.82)
}

// MARK: - Consistent glass surface (used everywhere)

struct GlassCard: ViewModifier {
    var radius: CGFloat = Theme.rMd
    var glow: Bool = false
    var glowColor: Color = Theme.accent
    var strokeOpacity: Double = 1
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial))
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface.opacity(0.4)))
            // Faint specular sheen along the top edge — subtle "liquid glass".
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.02), .clear],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(glow ? Theme.accent.opacity(0.55) : Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }
}
extension View {
    func glassCard(radius: CGFloat = Theme.rMd, glow: Bool = false, glowColor: Color = Theme.accent, strokeOpacity: Double = 1) -> some View {
        modifier(GlassCard(radius: radius, glow: glow, glowColor: glowColor, strokeOpacity: strokeOpacity))
    }
}

struct AppBackground: View { var body: some View { Theme.bg.ignoresSafeArea() } }
struct AuroraBackground: View { var intensity: Double = 1.0; var body: some View { AppBackground() } }

// MARK: - Malaysian pattern overlays (subtle, procedural)

enum PatternStyle: String, CaseIterable, Identifiable {
    case none, batik, songket, bungaRaya, klcc
    var id: String { rawValue }
    var label: String {
        let my = AppSettings.shared.language == .malay
        switch self {
        case .none: return my ? "Tiada" : "None"
        case .batik: return "Batik"
        case .songket: return "Songket"
        case .bungaRaya: return "Bunga Raya"
        case .klcc: return "KLCC"
        }
    }
}

/// A faint, tiling Malaysian-inspired motif for panels (sidebar, headers).
struct MalaysianPattern: View {
    var style: PatternStyle
    var tint: Color = Theme.accent
    var opacity: Double = 0.06

    var body: some View {
        Canvas { ctx, size in
            let c = GraphicsContext.Shading.color(tint.opacity(opacity))
            switch style {
            case .none: break
            case .batik: drawBatik(ctx, size, c)
            case .songket: drawSongket(ctx, size, c)
            case .bungaRaya: drawBunga(ctx, size, c)
            case .klcc: drawKLCC(ctx, size, c)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBatik(_ ctx: GraphicsContext, _ size: CGSize, _ c: GraphicsContext.Shading) {
        let step: CGFloat = 46
        var y: CGFloat = 0
        while y < size.height + step {
            var x: CGFloat = 0
            while x < size.width + step {
                var p = Path(); p.addArc(center: CGPoint(x: x, y: y), radius: 10, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
                ctx.stroke(p, with: c, lineWidth: 1)
                var p2 = Path(); p2.addArc(center: CGPoint(x: x, y: y), radius: 4, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
                ctx.fill(p2, with: c)
                x += step
            }
            y += step
        }
    }
    private func drawSongket(_ ctx: GraphicsContext, _ size: CGSize, _ c: GraphicsContext.Shading) {
        let step: CGFloat = 30
        var y: CGFloat = 0
        while y < size.height + step {
            var x: CGFloat = 0
            while x < size.width + step {
                var d = Path()
                d.move(to: CGPoint(x: x, y: y - 6)); d.addLine(to: CGPoint(x: x + 6, y: y))
                d.addLine(to: CGPoint(x: x, y: y + 6)); d.addLine(to: CGPoint(x: x - 6, y: y)); d.closeSubpath()
                ctx.stroke(d, with: c, lineWidth: 1)
                x += step
            }
            y += step
        }
    }
    private func drawBunga(_ ctx: GraphicsContext, _ size: CGSize, _ c: GraphicsContext.Shading) {
        let step: CGFloat = 58
        var y: CGFloat = 0
        while y < size.height + step {
            var x: CGFloat = 0
            while x < size.width + step {
                for i in 0..<5 {
                    let a = CGFloat(i) / 5 * .pi * 2
                    var pet = Path()
                    pet.addEllipse(in: CGRect(x: x + cos(a)*8 - 4, y: y + sin(a)*8 - 7, width: 8, height: 14))
                    ctx.stroke(pet, with: c, lineWidth: 0.8)
                }
                x += step
            }
            y += step
        }
    }
    private func drawKLCC(_ ctx: GraphicsContext, _ size: CGSize, _ c: GraphicsContext.Shading) {
        let step: CGFloat = 40
        var x: CGFloat = 0
        while x < size.width + step {
            var t = Path()
            t.move(to: CGPoint(x: x, y: size.height))
            t.addLine(to: CGPoint(x: x, y: size.height - 34))
            t.addLine(to: CGPoint(x: x + 5, y: size.height - 44))
            t.addLine(to: CGPoint(x: x + 10, y: size.height - 34))
            t.addLine(to: CGPoint(x: x + 10, y: size.height))
            ctx.stroke(t, with: c, lineWidth: 1)
            x += step
        }
    }
}

extension View {
    /// Overlay a subtle pattern following the user's setting.
    func patterned(_ scope: PatternScope = .panel, tint: Color = Theme.accent, opacity: Double = 0.06) -> some View {
        let style = PatternStyle(rawValue: AppSettings.shared.pattern) ?? .batik
        return self.overlay(MalaysianPattern(style: style, tint: tint, opacity: opacity).clipped())
    }

    /// Same subtle pattern, clipped to a rounded rectangle (floating panels).
    func patternedRounded(_ radius: CGFloat, tint: Color = Theme.accent, opacity: Double = 0.06) -> some View {
        let style = PatternStyle(rawValue: AppSettings.shared.pattern) ?? .batik
        return self.overlay(
            MalaysianPattern(style: style, tint: tint, opacity: opacity)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .allowsHitTesting(false)
        )
    }
}
enum PatternScope { case panel, full }

// MARK: - Buttons

struct ExpressiveButtonStyle: ButtonStyle {
    var prominent: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Theme.accent)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).fill(Theme.accentGradient)
                } else {
                    RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.snappy, value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.snappy, value: configuration.isPressed)
    }
}

// MARK: - Shimmer / Pressable

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.6).offset(x: phase * geo.size.width * 1.6)
            }.mask(content)
        )
        .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 } }
    }
}
extension View { func shimmering() -> some View { modifier(Shimmer()) } }

struct Pressable: ViewModifier {
    @State private var hover = false
    @State private var pressed = false
    var lift: CGFloat = 2
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.98 : hover ? 1.01 : 1).offset(y: hover ? -lift : 0)
            .animation(Theme.bouncy, value: hover).animation(Theme.snappy, value: pressed)
            .onHover { hover = $0 }
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
    }
}
extension View { func pressable(lift: CGFloat = 2) -> some View { modifier(Pressable(lift: lift)) } }
