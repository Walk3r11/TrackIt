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
            background: [Palette.card, Palette.cardAlt],
            stroke: [Palette.strokeStrong, Palette.stroke],
            glow: Palette.accent.opacity(0.12),
            accent: Palette.accent
        )
    ]

    static func theme(for card: CardInfo, index: Int? = nil) -> Theme {
        guard !presets.isEmpty else {
            return Theme(
                background: [Palette.card, Palette.card.opacity(0.9)],
                stroke: [Palette.accent, Palette.accentAlt],
                glow: Palette.accentGlow,
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
