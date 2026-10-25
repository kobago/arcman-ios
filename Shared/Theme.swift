import SwiftUI
import UIKit

extension ShapeStyle where Self == Color {
    static var bg: Color { Color(dark: 0x0e0f11, light: 0xf4f5f6) }
    static var panel: Color { Color(dark: 0x15171a, light: 0xffffff) }
    static var raised: Color { Color(dark: 0x1d2024, light: 0xffffff) }
    static var line: Color { Color(dark: 0x2c3036, light: 0xdcdfe3) }
    static var text: Color { Color(dark: 0xe9eaec, light: 0x16181b) }
    static var muted: Color { Color(dark: 0xa3a9b0, light: 0x596069) }
    static var selected: Color { Color(dark: 0x262a30, light: 0xe7e9ec) }
    static var accent: Color { Color(hex: 0xe6b450) }
    static var accentInk: Color { Color(hex: 0x1b1405) }
    static var accentText: Color { Color(dark: 0xe6b450, light: 0x8a5a00) }
    static var danger: Color { Color(dark: 0xf0a49a, light: 0xb3261e) }
    static var dangerLine: Color { Color(dark: 0x5a2f2a, light: 0xf0c4bf) }
    static var dangerFill: Color { Color(hex: 0xc2554a) }
    static var success: Color { Color(hex: 0x7cc49a) }
    static var stage: Color { Color(hex: 0x070808) }
    static var stageText: Color { Color(hex: 0xe9eaec) }
    static var scrim: Color { Color(uiColor: dynamicColor(dark: UIColor.black.withAlphaComponent(0.6), light: UIColor.black.withAlphaComponent(0.35))) }
    static var metalHi: Color { Color(dark: 0xf4f5f7, light: 0x3a3f45) }
    static var metalLo: Color { Color(dark: 0xb9bfc6, light: 0x16181b) }
    static var metalMid: Color { Color(dark: 0xd6dade, light: 0x26292d) }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(dark: UInt32, light: UInt32) {
        self.init(uiColor: dynamicColor(dark: UIColor(hex: dark), light: UIColor(hex: light)))
    }

    init?(css: String?) {
        guard let css, css.hasPrefix("#"), let value = UInt32(css.dropFirst(), radix: 16) else { return nil }
        self.init(hex: value)
    }
}

// SwiftUI resolves dynamic colors while rendering off the main thread, so the provider must not inherit main-actor isolation.
nonisolated private func dynamicColor(dark: UIColor, light: UIColor) -> UIColor {
    UIColor { $0.userInterfaceStyle == .light ? light : dark }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(red: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

extension Font {
    static func plex(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name = switch weight {
        case .semibold, .bold, .heavy, .black: "IBMPlexSansJP-SemiBold"
        case .medium: "IBMPlexSansJP-Medium"
        default: "IBMPlexSansJP-Regular"
        }
        return .custom(name, size: size)
    }

    static func mono(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .custom(weight == .regular ? "IBMPlexMono-Regular" : "IBMPlexMono-Medium", size: size).monospacedDigit()
    }
}

extension UIFont {
    static func plex(_ size: CGFloat, semibold: Bool = false) -> UIFont {
        UIFont(name: semibold ? "IBMPlexSansJP-SemiBold" : "IBMPlexSansJP-Regular", size: size) ?? .systemFont(ofSize: size)
    }
}

enum Theme: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plex(large ? 15 : 14, .semibold))
            .foregroundStyle(.accentInk)
            .padding(.horizontal, 16)
            .frame(minHeight: large ? 48 : 40)
            .background(.accent, in: .rect(cornerRadius: large ? 10 : 8))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var danger = false
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plex(small ? 13 : 14))
            .foregroundStyle(danger ? .danger : .text)
            .padding(.horizontal, small ? 12 : 16)
            .frame(minHeight: small ? 30 : 40)
            .background(danger ? Color.clear : Color.raised, in: .rect(cornerRadius: small ? 6 : 8))
            .overlay(RoundedRectangle(cornerRadius: small ? 6 : 8).stroke(danger ? .dangerLine : .line))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    func inputBox(focused: Bool = false, invalid: Bool = false, large: Bool = false) -> some View {
        padding(.horizontal, 12)
            .frame(minHeight: large ? 48 : 40)
            .background(.raised, in: .rect(cornerRadius: large ? 10 : 8))
            .overlay(RoundedRectangle(cornerRadius: large ? 10 : 8).stroke(invalid ? .dangerFill : focused ? .accent : .line))
    }
}
