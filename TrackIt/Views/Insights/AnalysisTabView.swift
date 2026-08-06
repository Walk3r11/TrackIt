import SwiftUI

struct AnalysisTabView: View {
    let stats: InsightStats
    let spendingVelocity: SpendingVelocity
    let savingsRate: SavingsRate
    let previousStats: InsightStats?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.Layout.sectionSpacing) {
                spendingVelocitySection
                savingsRateSection
                trendsSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var spendingVelocitySection: some View {
        InsightsSection(title: "Velocity", icon: "speedometer") {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                StatRow(
                    icon: "gauge.high",
                    title: "Spending Rate",
                    value: spendingVelocity.rate.formattedAsCurrency(suffix: "/day"),
                    iconColor: Palette.danger
                )

                StatRow(
                    icon: "clock.arrow.circlepath",
                    title: "Days to Depletion",
                    value: spendingVelocity.daysUntilDepletion > 0 ? "\(spendingVelocity.daysUntilDepletion)" : "N/A",
                    iconColor: Palette.warning
                )

                StatRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Projected Monthly",
                    value: spendingVelocity.projectedMonthly.formattedAsCurrency(),
                    iconColor: Palette.accentAlt
                )
                .gridCellColumns(2)
            }
        }
    }

    private var savingsRateSection: some View {
        InsightsSection(title: "Savings", icon: "banknote.fill") {
            VStack(spacing: 12) {
                StatCard(
                    title: "Savings Rate",
                    value: savingsRate.rate.formattedAsPercentage(),
                    icon: "percent",
                    color: savingsRate.rate >= AppConstants.Insights.recommendedSavingsRate ? Palette.success : Palette.warning,
                    change: nil
                )

                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    StatRow(
                        icon: "arrow.down.circle.fill",
                        title: "Total Saved",
                        value: savingsRate.totalSaved.formattedAsCurrency(),
                        iconColor: Palette.success
                    )

                    StatRow(
                        icon: "target",
                        title: "Recommended Rate",
                        value: "\(Int(AppConstants.Insights.recommendedSavingsRate))%",
                        iconColor: Palette.accent
                    )
                }

                if savingsRate.rate < AppConstants.Insights.recommendedSavingsRate {
                    SavingsWarningBanner()
                }
            }
        }
    }

    private var trendsSection: some View {
        InsightsSection(title: "Trends", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 16) {
                if let previousStats = previousStats {
                    TrendRow(
                        title: "Income Trend",
                        current: stats.income,
                        previous: previousStats.income,
                        icon: "arrow.down.circle.fill",
                        color: Palette.success
                    )

                    TrendRow(
                        title: "Expenses Trend",
                        current: stats.expenses,
                        previous: previousStats.expenses,
                        icon: "arrow.up.circle.fill",
                        color: Palette.danger
                    )

                    TrendRow(
                        title: "Net Balance Trend",
                        current: stats.net,
                        previous: previousStats.net,
                        icon: "equal.circle.fill",
                        color: stats.net >= 0 ? Palette.success : Palette.danger
                    )
                } else {
                    EmptyDataView(message: "Insufficient data for trend analysis")
                }
            }
        }
    }

}
