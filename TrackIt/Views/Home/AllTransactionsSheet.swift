import SwiftUI

struct AllTransactionsSheet: View {
    var transactions: [Transaction]
    var onAdd: () -> Void
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if transactions.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "tray")
                                    .font(.appFont(size: 32, weight: .medium))
                                    .foregroundColor(Palette.secondary)
                                Text("No transactions yet")
                                    .font(.appFont(size: 16, weight: .semibold))
                                    .foregroundColor(Palette.primary)
                                Text("Add a transaction to see it here.")
                                    .font(.appFont(size: 12))
                                    .foregroundColor(Palette.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(transactions) { transaction in
                                    TransactionRow(
                                        title: transaction.category,
                                        subtitle: Self.dateFormatter.string(from: transaction.date),
                                        amountText: formattedAmount(for: transaction),
                                        tint: transaction.kind == .income ? Palette.accentAlt : Palette.accent
                                    )
                                    .padding(.horizontal, 16)
                                    .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: LayoutMetrics.maxContentWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("All Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onAdd()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func formattedAmount(for transaction: Transaction) -> String {
        let formatted = abs(transaction.amount).formatted(.currency(code: AppConstants.Currency.code))
        return "\(transaction.kind == .income ? "+" : "-")\(formatted)"
    }
}
