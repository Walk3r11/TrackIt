import SwiftUI

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: [Color] = [Palette.accentAlt, Palette.accent]
    var shadowColor: Color? = nil
    var darkOverlayOpacity: Double = 0

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let shadow = shadowColor ?? tint.first ?? Palette.accent

        return content
            .background(.regularMaterial, in: shape)
            .overlay(
                Color.black.opacity(darkOverlayOpacity)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            )
            .overlay(
                Color.white.opacity(0.06)
                    .clipShape(shape)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            )
            .overlay(
                LinearGradient(
                    colors: tint.map { $0.opacity(0.18) } + [Color.white.opacity(0.01)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
                .clipShape(shape)
                .allowsHitTesting(false)
            )
            .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
            .overlay(shape.stroke(Color.white.opacity(0.06), lineWidth: 2).blur(radius: 0.7).allowsHitTesting(false))
            .shadow(color: shadow.opacity(0.20), radius: 26, x: 0, y: 18)
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        tint: [Color] = [Palette.accentAlt, Palette.accent],
        shadowColor: Color? = nil,
        darkOverlayOpacity: Double = 0
    ) -> some View {
        modifier(
            GlassCardStyle(
                cornerRadius: cornerRadius,
                tint: tint,
                shadowColor: shadowColor,
                darkOverlayOpacity: darkOverlayOpacity
            )
        )
    }
}
