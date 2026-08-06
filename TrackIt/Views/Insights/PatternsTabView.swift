import SwiftUI

struct PatternsTabView: View {
    let spendingPatterns: SpendingPatterns
    let monthlyComparison: [MonthlyData]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.Layout.sectionSpacing) {
                spendingPatternsSection
                monthlyComparisonSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var spendingPatternsSection: some View {
        InsightsSection(title: "Behavior", icon: "clock.fill") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                StatRow(
                    icon: "calendar.badge.clock",
                    title: "Most Active Day",
                    value: spendingPatterns.mostActiveDay,
                    iconColor: Palette.accent
                )

                StatRow(
                    icon: "calendar.badge.exclamationmark",
                    title: "Peak Spending Day",
                    value: spendingPatterns.peakSpendingDay,
                    iconColor: Palette.danger
                )

                StatRow(
                    icon: "hourglass",
                    title: "Avg Time Between",
                    value: spendingPatterns.avgTimeBetweenTx,
                    iconColor: Palette.warning
                )

                StatRow(
                    icon: "chart.bar.fill",
                    title: "Daily Average",
                    value: spendingPatterns.dailyAverage.formattedAsCurrency(),
                    iconColor: Palette.accentAlt
                )
            }
        }
    }

    private var monthlyComparisonSection: some View {
        InsightsSection(title: "Monthly Comparison", icon: "calendar") {
            if monthlyComparison.isEmpty {
                EmptyDataView(message: "Insufficient data for monthly comparison")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(monthlyComparison.prefix(AppConstants.Insights.maxMonthsInComparison).enumerated()), id: \.offset) { _, month in
                        MonthlyComparisonRow(
                            month: month.month,
                            income: month.income,
                            expenses: month.expenses,
                            net: month.net
                        )
                    }
                }
            }
        }
    }

}
