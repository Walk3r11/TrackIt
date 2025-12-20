import SwiftUI

enum CardTheme {
    struct Theme {
        let background: [Color]
        let stroke: [Color]
        let glow: Color
        let accent: Color
    }

    private static let presets: [Theme] = [
        Theme(
            background: [
                Color(red: 0.10, green: 0.15, blue: 0.32),
                Color(red: 0.09, green: 0.28, blue: 0.52),
                Color(red: 0.14, green: 0.34, blue: 0.64)
            ],
            stroke: [
                Color(red: 0.45, green: 0.74, blue: 1.0),
                Color(red: 0.30, green: 0.62, blue: 0.98)
            ],
            glow: Color(red: 0.28, green: 0.62, blue: 0.98),
            accent: Color(red: 0.45, green: 0.74, blue: 1.0)
        ),
        Theme(
            background: [
                Color(red: 0.25, green: 0.11, blue: 0.32),
                Color(red: 0.40, green: 0.17, blue: 0.46),
                Color(red: 0.20, green: 0.08, blue: 0.28)
            ],
            stroke: [
                Color(red: 0.94, green: 0.55, blue: 0.92),
                Color(red: 0.68, green: 0.46, blue: 1.0)
            ],
            glow: Color(red: 0.84, green: 0.35, blue: 0.79),
            accent: Color(red: 0.86, green: 0.48, blue: 0.93)
        ),
        Theme(
            background: [
                Color(red: 0.07, green: 0.24, blue: 0.26),
                Color(red: 0.10, green: 0.38, blue: 0.36),
                Color(red: 0.08, green: 0.30, blue: 0.34)
            ],
            stroke: [
                Color(red: 0.42, green: 0.86, blue: 0.76),
                Color(red: 0.26, green: 0.70, blue: 0.82)
            ],
            glow: Color(red: 0.30, green: 0.80, blue: 0.72),
            accent: Color(red: 0.42, green: 0.86, blue: 0.76)
        ),
        Theme(
            background: [
                Color(red: 0.30, green: 0.18, blue: 0.08),
                Color(red: 0.38, green: 0.22, blue: 0.12),
                Color(red: 0.24, green: 0.14, blue: 0.06)
            ],
            stroke: [
                Color(red: 1.0, green: 0.72, blue: 0.46),
                Color(red: 0.96, green: 0.54, blue: 0.26)
            ],
            glow: Color(red: 0.98, green: 0.62, blue: 0.32),
            accent: Color(red: 1.0, green: 0.72, blue: 0.46)
        ),
        Theme(
            background: [
                Color(red: 0.12, green: 0.10, blue: 0.32),
                Color(red: 0.18, green: 0.16, blue: 0.46),
                Color(red: 0.22, green: 0.18, blue: 0.52)
            ],
            stroke: [
                Color(red: 0.54, green: 0.64, blue: 1.0),
                Color(red: 0.50, green: 0.32, blue: 1.0)
            ],
            glow: Color(red: 0.48, green: 0.42, blue: 1.0),
            accent: Color(red: 0.54, green: 0.64, blue: 1.0)
        ),
        Theme(
            background: [
                Color(red: 0.34, green: 0.13, blue: 0.20),
                Color(red: 0.46, green: 0.18, blue: 0.28),
                Color(red: 0.28, green: 0.10, blue: 0.18)
            ],
            stroke: [
                Color(red: 0.98, green: 0.58, blue: 0.68),
                Color(red: 0.98, green: 0.72, blue: 0.52)
            ],
            glow: Color(red: 0.98, green: 0.58, blue: 0.68),
            accent: Color(red: 0.98, green: 0.58, blue: 0.68)
        )
    ]

    static func theme(for card: CardInfo, index: Int? = nil) -> Theme {
        guard !presets.isEmpty else {
            return Theme(
                background: [Palette.card, Palette.card.opacity(0.9)],
                stroke: [Palette.accent, Palette.accentAlt],
                glow: Palette.accent,
                accent: Palette.accent
            )
        }
        if let idx = index {
            return presets[idx % presets.count]
        }
        
        let scalars = card.id.uuidString.unicodeScalars
        let checksum = scalars.reduce(UInt64(0)) { partial, scalar in
            (partial &* 31) &+ UInt64(scalar.value)
        }
        let idx = Int(checksum % UInt64(presets.count))
        return presets[idx]
    }
}
