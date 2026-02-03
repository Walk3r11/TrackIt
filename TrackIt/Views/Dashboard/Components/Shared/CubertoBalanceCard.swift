import SwiftUI

struct CubertoBalanceCard: View {
    var title: String
    var amountText: String
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.appFont(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.primary.opacity(0.95))
                Text(amountText)
                    .font(.appFont(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }

            Spacer()

            if let action {
                Button(action: action) {
                    Image(systemName: "arrow.right")
                        .font(.appFont(size: 15, weight: .bold))
                        .foregroundColor(Palette.primary)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Palette.card)
                        )
                        .overlay(
                            Circle()
                                .stroke(Palette.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glassCard(
            cornerRadius: 26,
            tint: [Palette.accentAlt, Palette.accent],
            shadowColor: Palette.shadowStrong
        )
    }
}
