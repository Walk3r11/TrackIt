import Foundation

struct InsightStats: Equatable, Sendable {
    let income: Double

    let expenses: Double

    let net: Double

    let transactionCount: Int

    let incomeCount: Int

    let expenseCount: Int

    let avgTransaction: Double

    let transactionsPerDay: Double

    let topExpenseCategories: [(name: String, amount: Double, percentage: Double)]

    let topIncomeCategories: [(name: String, amount: Double, percentage: Double)]

    let incomeChange: Double?

    let expensesChange: Double?

    let netChange: Double?

    static let empty = InsightStats(
        income: 0,
        expenses: 0,
        net: 0,
        transactionCount: 0,
        incomeCount: 0,
        expenseCount: 0,
        avgTransaction: 0,
        transactionsPerDay: 0,
        topExpenseCategories: [],
        topIncomeCategories: [],
        incomeChange: nil,
        expensesChange: nil,
        netChange: nil
    )

    // MARK: - Equatable

    static func == (lhs: InsightStats, rhs: InsightStats) -> Bool {
        lhs.income == rhs.income &&
        lhs.expenses == rhs.expenses &&
        lhs.net == rhs.net &&
        lhs.transactionCount == rhs.transactionCount
    }
}

// MARK: - Spending Patterns

struct SpendingPatterns: Equatable, Sendable {
    let mostActiveDay: String

    let peakSpendingDay: String

    let avgTimeBetweenTx: String

    let dailyAverage: Double

    static let empty = SpendingPatterns(
        mostActiveDay: "N/A",
        peakSpendingDay: "N/A",
        avgTimeBetweenTx: "N/A",
        dailyAverage: 0
    )
}

// MARK: - Monthly Data

struct MonthlyData: Identifiable, Equatable, Sendable {
    let id = UUID()

    let month: String

    let income: Double

    let expenses: Double

    let net: Double

    static func == (lhs: MonthlyData, rhs: MonthlyData) -> Bool {
        lhs.month == rhs.month &&
        lhs.income == rhs.income &&
        lhs.expenses == rhs.expenses
    }
}

// MARK: - Transaction Data

struct TransactionData: Identifiable, Equatable, Sendable {
    let id = UUID()

    let category: String

    let amount: Double

    let date: Date

    let isExpense: Bool
}

// MARK: - Spending Velocity

struct SpendingVelocity: Equatable, Sendable {
    let rate: Double

    let daysUntilDepletion: Int

    let projectedMonthly: Double

    static let empty = SpendingVelocity(
        rate: 0,
        daysUntilDepletion: 0,
        projectedMonthly: 0
    )
}

// MARK: - Savings Rate

struct SavingsRate: Equatable, Sendable {
    let rate: Double

    let totalSaved: Double

    static let empty = SavingsRate(rate: 0, totalSaved: 0)
}

// MARK: - Card Stats

struct CardStats: Equatable, Sendable {
    let totalSpending: Double

    let cardsOverLimit: Int

    let avgSpendingPerCard: Double?

    static let empty = CardStats(
        totalSpending: 0,
        cardsOverLimit: 0,
        avgSpendingPerCard: nil
    )
}
