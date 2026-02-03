import SwiftUI

struct CategoriesTabView: View {
    let stats: InsightStats

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.Layout.sectionSpacing) {
                spendingCategoriesSection
                incomeCategoriesSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var spendingCategoriesSection: some View {
        InsightsSection(title: "Expense Mix", icon: "tray.full.fill") {
            let slices = makeCategorySlices(from: stats.topExpenseCategories)
            CategoryDonutBlock(
                title: "Top expense categories",
                totalText: stats.expenses.formattedAsCurrency(),
                slices: slices,
                emptyText: "No spending data available"
            )
        }
    }

    private var incomeCategoriesSection: some View {
        InsightsSection(title: "Income Mix", icon: "arrow.down.circle.fill") {
            let slices = makeCategorySlices(from: stats.topIncomeCategories)
            CategoryDonutBlock(
                title: "Top income categories",
                totalText: stats.income.formattedAsCurrency(),
                slices: slices,
                emptyText: "No income data available"
            )
        }
    }

}
