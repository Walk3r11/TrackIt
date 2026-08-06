import SwiftUI

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 22
    var tint: [Color] = [Palette.accentAlt, Palette.accent]
    var shadowColor: Color? = nil
    var darkOverlayOpacity: Double = 0
    var useMaterial: Bool = false

    func body(content: Content) -> some View {
        content
            .minimalSurface(cornerRadius: cornerRadius, fill: Palette.cardAlt, stroke: Palette.stroke)
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = 22,
        tint: [Color] = [Palette.accentAlt, Palette.accent],
        shadowColor: Color? = nil,
        darkOverlayOpacity: Double = 0,
        useMaterial: Bool = false
    ) -> some View {
        modifier(
            GlassCardStyle(
                cornerRadius: cornerRadius,
                tint: tint,
                shadowColor: shadowColor,
                darkOverlayOpacity: darkOverlayOpacity,
                useMaterial: useMaterial
            )
        )
    }

    func softInset(cornerRadius: CGFloat = 16) -> some View {
        modifier(SoftInsetStyle(cornerRadius: cornerRadius))
    }
}

struct SoftInsetStyle: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .minimalSurface(cornerRadius: cornerRadius, fill: Palette.card, stroke: Palette.strokeStrong)
    }
}
