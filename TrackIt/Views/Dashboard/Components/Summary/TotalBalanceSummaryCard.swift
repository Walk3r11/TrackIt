import SwiftUI

struct TotalBalanceSummaryCard: View {
    var periodTitle: String
    var amountText: String
    var cardsCount: Int
    var averageSpentText: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("Total Balance")
                        .font(.appFont(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(Palette.secondary)

                    Text("\(cardsCount) \(cardsCount == 1 ? "card" : "cards")")
                        .font(.appFont(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.primary.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Palette.mutedFill)
                                .overlay(
                                    Capsule()
                                        .stroke(Palette.stroke, lineWidth: 1)
                                )
                        )
                }

                Text(amountText)
                    .font(.appFont(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 12) {
                    Text(periodTitle)
                        .font(.appFont(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.tertiary)
                        .textCase(.uppercase)
                        .kerning(0.5)

                    AverageSpentPill(valueText: averageSpentText)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 140)
        .glassCard(
            cornerRadius: 24,
            tint: [Palette.cardAlt, Palette.card],
            shadowColor: Palette.shadowStrong
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Palette.accent)
                .frame(width: 46, height: 4)
                .padding(.top, 12)
                .padding(.leading, 20)
        }
    }
}
