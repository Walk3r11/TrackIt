import SwiftUI

struct QuickActionRow: View {
    var icon: String
    var title: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.card)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.35), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.appFont(size: 14, weight: .semibold))
                            .foregroundColor(tint)
                    )

                Text(title)
                    .font(.appFont(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.appFont(size: 10, weight: .semibold))
                    .foregroundColor(Palette.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 1)
            )
            .shadow(color: Palette.highlight, radius: 4, x: -2, y: -2)
            .shadow(color: Palette.shadow, radius: 4, x: 2, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
