import SwiftUI

struct TransactionsTabView: View {
    let stats: InsightStats
    let cardStats: CardStats
    let largestTransactions: [TransactionData]
    let cardsCount: Int

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.Layout.sectionSpacing) {
                transactionStatsSection
                cardStatsSection
                largestTransactionsSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var transactionStatsSection: some View {
        InsightsSection(title: "Activity", icon: "list.bullet.rectangle.fill") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                StatRow(
                    icon: "number.circle.fill",
                    title: "Total Transactions",
                    value: "\(stats.transactionCount)",
                    iconColor: Palette.accent
                )

                StatRow(
                    icon: "eurosign.circle.fill",
                    title: "Average Transaction",
                    value: stats.avgTransaction.formattedAsCurrency(),
                    iconColor: Palette.accentAlt
                )

                StatRow(
                    icon: "arrow.down.circle.fill",
                    title: "Income Transactions",
                    value: "\(stats.incomeCount)",
                    iconColor: Palette.success
                )

                StatRow(
                    icon: "arrow.up.circle.fill",
                    title: "Expense Transactions",
                    value: "\(stats.expenseCount)",
                    iconColor: Palette.danger
                )

                StatRow(
                    icon: "calendar.circle.fill",
                    title: "Transactions per Day",
                    value: String(format: "%.1f", stats.transactionsPerDay),
                    iconColor: Palette.warning
                )
                .gridCellColumns(2)
            }
        }
    }

    private var cardStatsSection: some View {
        InsightsSection(title: "Cards", icon: "creditcard.fill") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                StatRow(
                    icon: "creditcard.circle.fill",
                    title: "Total Cards",
                    value: "\(cardsCount)",
                    iconColor: Palette.accent
                )

                StatRow(
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    title: "Total Spending",
                    value: cardStats.totalSpending.formattedAsCurrency(),
                    iconColor: Palette.danger
                )

                StatRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Cards Over Limit",
                    value: "\(cardStats.cardsOverLimit)",
                    iconColor: Palette.warning
                )

                if let avgSpending = cardStats.avgSpendingPerCard {
                    StatRow(
                        icon: "equal.circle.fill",
                        title: "Avg per Card",
                        value: avgSpending.formattedAsCurrency(),
                        iconColor: Palette.accentAlt
                    )
                }
            }
        }
    }

    private var largestTransactionsSection: some View {
        InsightsSection(title: "Largest Transactions", icon: "arrow.up.circle.fill") {
            if largestTransactions.isEmpty {
                EmptyDataView(message: "No transaction data available")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(largestTransactions.prefix(AppConstants.Insights.maxMonthsInComparison).enumerated()), id: \.offset) { index, tx in
                        InsightTransactionRow(
                            rank: index + 1,
                            category: tx.category,
                            amount: tx.amount,
                            date: tx.date,
                            isExpense: tx.isExpense
                        )
                    }
                }
            }
        }
    }

}
