import SwiftUI

enum InsightSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case categories = "Categories"
    case transactions = "Transactions"
    case patterns = "Patterns"
    case analysis = "Analysis"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .categories: return "tag.fill"
        case .transactions: return "list.bullet.rectangle.fill"
        case .patterns: return "clock.fill"
        case .analysis: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum InsightTimeFrame: String, CaseIterable, Identifiable {
    case week = "Past Week"
    case month = "Past Month"
    case quarter = "Past 3 Months"
    case year = "Past Year"
    case all = "All Time"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .all: return nil
        }
    }
}

struct InsightSnapshot {
    var transactions: [Transaction]
    var cards: [CardInfo]
    var timeframeDays: Int?
    var balance: Double
    var selectedSection: InsightSection
}

struct SectionResults {
    var patterns: SpendingPatterns?
    var monthlyComparison: [MonthlyData]?
    var largest: [TransactionData]?
    var cardStats: CardStats?
    var velocity: SpendingVelocity?
    var savingsRate: SavingsRate?
    var previous: InsightStats?
    var stats: InsightStats?
}

struct CategorySlice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let value: Double
    let percentage: Double
    let color: Color
}

// MARK: - Helper Functions

func makeCategorySlices(
    from categories: [(name: String, amount: Double, percentage: Double)],
    limit: Int = AppConstants.Insights.maxCategoriesInChart
) -> [CategorySlice] {
    Array(categories.prefix(limit)).map { entry in
        CategorySlice(
            name: entry.name,
            value: entry.amount,
            percentage: entry.percentage,
            color: CategoryColors.color(for: entry.name)
        )
    }
}
