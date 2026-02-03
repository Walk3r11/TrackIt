import SwiftUI

struct RecentTransactionsCard: View {
    var transactions: [Transaction]
    var onViewAll: () -> Void
    var onAdd: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()


    private var transactionRows: [TransactionRowData] {
        transactions.map { tx in
            TransactionRowData(
                id: tx.id,
                title: tx.category,
                subtitle: Self.dateFormatter.string(from: tx.date),
                amountText: formattedAmount(for: tx),
                tint: tx.kind == .income ? Palette.success : Palette.danger,
                categoryColor: CategoryColors.color(for: tx.category),
                icon: iconName(for: tx.category)
            )
        }
    }

    private func iconName(for category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("food") || lower.contains("restaurant") || lower.contains("cafe") { return "fork.knife" }
        if lower.contains("rent") || lower.contains("home") { return "house.fill" }
        if lower.contains("uber") || lower.contains("taxi") || lower.contains("transport") { return "car.fill" }
        if lower.contains("shopping") || lower.contains("amazon") { return "bag.fill" }
        if lower.contains("salary") || lower.contains("pay") { return "creditcard.fill" }
        return "circle.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Transactions")
                    .font(.appFont(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(Palette.primary)
                Spacer()
                Button(action: onViewAll) {
                    Image(systemName: "chevron.right")
                        .font(.appFont(size: 11, weight: .semibold))
                        .foregroundColor(Palette.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Palette.card)
                        )
                }
                .buttonStyle(PressableButtonStyle(scale: 0.96, pressedOpacity: 0.85))
            }

            if transactions.isEmpty {
                EmptyStateView(
                    title: "No transactions yet",
                    message: "Tap + to add your first one."
                )
            } else {
                let rows = transactionRows
                let lastId = rows.last?.id
                LazyVStack(spacing: 0) {
                    ForEach(rows, id: \.id) { rowData in
                        OptimizedTransactionRow(
                            title: rowData.title,
                            subtitle: rowData.subtitle,
                            amountText: rowData.amountText,
                            tint: rowData.tint,
                            categoryColor: rowData.categoryColor,
                            icon: rowData.icon
                        )
                        .id(rowData.id)
                        if rowData.id != lastId {
                            Divider()
                                .background(Palette.stroke)
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard(
            cornerRadius: 20,
            tint: [Palette.cardAlt, Palette.card],
            shadowColor: Palette.shadowStrong
        )
        .drawingGroup()
    }

    private func formattedAmount(for tx: Transaction) -> String {
        let sign = tx.kind == .income ? "+" : "-"
        let absValue = abs(tx.amount)
        return "\(sign)\(absValue.formattedAsCurrency())"
    }
}


private struct TransactionRowData: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let amountText: String
    let tint: Color
    let categoryColor: Color
    let icon: String
}


private struct OptimizedTransactionRow: View, Equatable {
    var title: String
    var subtitle: String
    var amountText: String
    var tint: Color
    var categoryColor: Color
    var icon: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Palette.cardAlt)
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.appFont(size: 18, weight: .bold))
                    .foregroundColor(categoryColor)
            }
            .overlay(
                Circle()
                    .stroke(Palette.stroke, lineWidth: 1.0)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.appFont(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.primary)
                Text(subtitle)
                    .font(.appFont(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondary)
            }

            Spacer()

            Text(amountText)
                .font(.appFont(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .shadow(color: tint.opacity(0.25), radius: 2, y: 1)
        }
        .padding(.vertical, 16)
        .drawingGroup()
    }

    static func == (lhs: OptimizedTransactionRow, rhs: OptimizedTransactionRow) -> Bool {
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.amountText == rhs.amountText &&
        lhs.tint == rhs.tint &&
        lhs.categoryColor == rhs.categoryColor &&
        lhs.icon == rhs.icon
    }
}
