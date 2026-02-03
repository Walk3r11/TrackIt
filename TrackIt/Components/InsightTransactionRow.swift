import SwiftUI

struct InsightTransactionRow: View {
    let rank: Int
    let category: String
    let amount: Double
    let date: Date
    let isExpense: Bool

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            rankBadge
            transactionInfo
            Spacer()
            amountText
        }
        .padding(12)
        .minimalSurface(cornerRadius: 14, fill: Palette.card)
    }

    private var rankBadge: some View {
        Circle()
            .fill(Palette.cardAlt)
            .frame(width: 34, height: 34)
            .overlay(
                Text("\(rank)")
                    .font(.appFont(size: 12, weight: .semibold))
                    .foregroundColor(Palette.secondary)
            )
    }

    private var transactionInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Palette.primary)
            Text(Self.dateFormatter.string(from: date))
                .font(.caption)
                .foregroundColor(Palette.secondary)
        }
    }

    private var amountText: some View {
        Text(amount.formattedAsCurrency())
            .font(.subheadline.weight(.bold))
            .foregroundColor(tintColor)
    }

    private var tintColor: Color {
        isExpense ? Palette.danger : Palette.success
    }
}

// MARK: - Preview

#Preview {
    InsightTransactionRow(
        rank: 1,
        category: "Rent",
        amount: 1500,
        date: Date(),
        isExpense: true
    )
    .padding()
}
