import SwiftUI

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: [Color] = [Palette.accentAlt, Palette.accent]
    var shadowColor: Color? = nil
    var darkOverlayOpacity: Double = 0
    var useMaterial: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let shadow = shadowColor ?? tint.first ?? Palette.accent
        let baseShadowOpacity = useMaterial ? 0.15 : 0.10
        let shadowRadius: CGFloat = useMaterial ? 16 : 12
        let shadowY: CGFloat = useMaterial ? 12 : 8

        return content
            .background(
                Group {
                    if useMaterial {
                        shape.fill(.regularMaterial)
                    } else {
                        shape.fill(Palette.cardAlt)
                    }
                }
            )
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
            .shadow(color: shadow.opacity(baseShadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        tint: [Color] = [Palette.accentAlt, Palette.accent],
        shadowColor: Color? = nil,
        darkOverlayOpacity: Double = 0,
        useMaterial: Bool = true
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
}
