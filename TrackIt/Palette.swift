import SwiftUI

enum Palette {
    // MARK: - Background Colors (Paper)
    static let background = Color(red: 0.97, green: 0.97, blue: 0.95)
    static let backgroundTop = background
    static let backgroundMid = background
    static let backgroundBottom = background

    // MARK: - Surfaces (Paper + Ink)
    static let card = Color.white.opacity(0.96)
    static let cardAlt = Color.white.opacity(0.9)
    static let cardElevated = Color.white

    // MARK: - Border & Stroke (Minimal)
    static let stroke = Color.black.opacity(0.08)
    static let strokeStrong = Color.black.opacity(0.14)
    static let strokeGlow = stroke

    // MARK: - Text Colors (Ink)
    static let primary = Color.black
    static let secondary = Color.black.opacity(0.6)
    static let tertiary = Color.black.opacity(0.4)

    // MARK: - Accent Colors (Ink)
    static let accent = Color.black
    static let accentAlt = Color.black.opacity(0.85)
    static let accentGlow = accent

    // MARK: - Semantic Colors (Muted)
    static let success = Color(red: 0.16, green: 0.56, blue: 0.38)
    static let danger = Color(red: 0.70, green: 0.24, blue: 0.22)
    static let warning = Color(red: 0.77, green: 0.49, blue: 0.18)
    static let info = Color(red: 0.20, green: 0.40, blue: 0.76)

    // MARK: - UI Elements (Subtle)
    static let mutedFill = Color.black.opacity(0.04)
    static let mutedFillStrong = Color.black.opacity(0.08)
    static let mutedGlow = Color.black.opacity(0.12)
    static let overlay = Color.black.opacity(0.04)
    static let shadow = Color.black.opacity(0.05)
    static let shadowStrong = Color.black.opacity(0.1)
    static let highlight = Color.white.opacity(0.2)
}
