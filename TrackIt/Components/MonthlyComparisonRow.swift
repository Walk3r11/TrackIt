import SwiftUI

struct MonthlyComparisonRow: View {
    let month: String
    let income: Double
    let expenses: Double
    let net: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(month)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
                Spacer()
                Text(net.formattedAsCurrency())
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(net >= 0 ? Palette.success : Palette.danger)
            }

            HStack(spacing: 12) {
                amountColumn(title: "Income", amount: income, color: Palette.success)
                amountColumn(title: "Expenses", amount: expenses, color: Palette.danger)
            }
        }
        .padding(14)
        .minimalSurface(cornerRadius: 14, fill: Palette.card)
    }

    private func amountColumn(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(Palette.secondary)
            Text(amount.formattedAsCurrency())
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview {
    MonthlyComparisonRow(
        month: "January 2026",
        income: 5000,
        expenses: 3500,
        net: 1500
    )
    .padding()
}
