import SwiftUI

struct OverviewTabView: View {
    let stats: InsightStats

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.Layout.sectionSpacing) {
                overviewSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var overviewSection: some View {
        InsightsSection(title: "Snapshot", icon: "sparkles") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(
                    title: "Total Income",
                    value: stats.income.formattedAsCurrency(),
                    icon: "arrow.down.circle.fill",
                    color: Palette.success,
                    change: stats.incomeChange
                )

                StatCard(
                    title: "Total Expenses",
                    value: stats.expenses.formattedAsCurrency(),
                    icon: "arrow.up.circle.fill",
                    color: Palette.danger,
                    change: stats.expensesChange
                )

                StatCard(
                    title: "Net Balance",
                    value: stats.net.formattedAsCurrency(),
                    icon: "equal.circle.fill",
                    color: stats.net >= 0 ? Palette.success : Palette.danger,
                    change: stats.netChange
                )
                .gridCellColumns(2)
            }
        }
    }

}
