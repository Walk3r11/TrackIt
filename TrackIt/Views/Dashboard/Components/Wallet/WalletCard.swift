import SwiftUI

struct WalletCard: View {
    var title: String
    var limitText: String?
    var amountText: String
    var values: [Double]
    var isOverLimit: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.appFont(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(Palette.primary)

                if let limitText {
                    Text(limitText)
                        .font(.appFont(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(isOverLimit ? Palette.danger : Palette.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Palette.cardAlt)
                        )
                        .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()
            }

            Text(amountText)
                .font(.appFont(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            LineSpark(values: values, accent: Palette.accent)
                .frame(height: 54)
        }
        .padding(22)
        .glassCard(
            cornerRadius: 24,
            tint: [Palette.cardAlt, Palette.card],
            shadowColor: Palette.shadowStrong
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Palette.accent)
                .frame(width: 52, height: 4)
                .padding(.top, 14)
                .padding(.leading, 22)
        }
        .drawingGroup()
    }
}
