import SwiftUI

struct MinimalBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.background, Color(red: 0.94, green: 0.95, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.black.opacity(0.05))
                .frame(width: 220, height: 220)
                .offset(x: -140, y: -200)

            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .frame(width: 260, height: 180)
                .rotationEffect(.degrees(-12))
                .offset(x: 160, y: -120)

            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                .frame(width: 320, height: 320)
                .offset(x: 180, y: 240)
        }
    }
}

struct MinimalSurface: ViewModifier {
    var cornerRadius: CGFloat = 18
    var fill: Color = Palette.card
    var stroke: Color = Palette.stroke

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}

extension View {
    func minimalSurface(
        cornerRadius: CGFloat = 18,
        fill: Color = Palette.card,
        stroke: Color = Palette.stroke
    ) -> some View {
        modifier(MinimalSurface(cornerRadius: cornerRadius, fill: fill, stroke: stroke))
    }
}
