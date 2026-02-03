import Foundation

struct InsightsCalculator: Sendable {

    // MARK: - Date Formatter

    private static let monthlyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    // MARK: - Transaction Filtering

    func filterTransactions(snapshot: InsightSnapshot) -> [Transaction] {
        guard let days = snapshot.timeframeDays else {
            return snapshot.transactions
        }
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return snapshot.transactions
        }
        return snapshot.transactions.filter { $0.date >= cutoffDate }
    }

    // MARK: - Stats Calculation

    func calculateStats(
        from filtered: [Transaction],
        snapshot: InsightSnapshot,
        previousStats: InsightStats?
    ) -> InsightStats {
        var income: Double = 0
        var expenses: Double = 0
        var incomeCount = 0
        var expenseCount = 0

        for tx in filtered {
            if tx.kind == .income {
                income += tx.amount
                incomeCount += 1
            } else {
                expenses += abs(tx.amount)
                expenseCount += 1
            }
        }

        let net = income - expenses
        let totalCount = filtered.count
        let avgTransaction = totalCount > 0 ? (income + expenses) / Double(totalCount) : 0

        let days = snapshot.timeframeDays ?? calculateDaysSinceFirst(transactions: snapshot.transactions)
        let transactionsPerDay = days > 0 ? Double(totalCount) / Double(days) : 0

        let (topExpenseCategories, topIncomeCategories) = calculateCategoryBreakdowns(
            filtered: filtered,
            totalExpenses: expenses,
            totalIncome: income
        )

        let incomeChange = previousStats.flatMap { income.percentageChange(from: $0.income) }
        let expensesChange = previousStats.flatMap { expenses.percentageChange(from: $0.expenses) }
        let netChange = previousStats.flatMap { net.percentageChange(from: $0.net) }

        return InsightStats(
            income: income,
            expenses: expenses,
            net: net,
            transactionCount: totalCount,
            incomeCount: incomeCount,
            expenseCount: expenseCount,
            avgTransaction: avgTransaction,
            transactionsPerDay: transactionsPerDay,
            topExpenseCategories: topExpenseCategories,
            topIncomeCategories: topIncomeCategories,
            incomeChange: incomeChange,
            expensesChange: expensesChange,
            netChange: netChange
        )
    }

    // MARK: - Spending Patterns

    func calculateSpendingPatterns(
        from filtered: [Transaction],
        snapshot: InsightSnapshot
    ) -> SpendingPatterns {
        let calendar = Calendar.current

        var dayOfWeekSpending: [Int: (count: Int, amount: Double)] = [:]
        var dayOfWeekCounts: [Int: Int] = [:]

        for tx in filtered where tx.kind == .expense {
            let weekday = calendar.component(.weekday, from: tx.date)
            var current = dayOfWeekSpending[weekday, default: (0, 0)]
            current.amount += abs(tx.amount)
            current.count += 1
            dayOfWeekSpending[weekday] = current
            dayOfWeekCounts[weekday, default: 0] += 1
        }

        let mostActiveDayNum = dayOfWeekCounts.max(by: { $0.value < $1.value })?.key ?? 1
        let peakSpendingDayNum = dayOfWeekSpending.max(by: { $0.value.amount < $1.value.amount })?.key ?? 1

        let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let mostActiveDay = weekdayNames[mostActiveDayNum]
        let peakSpendingDay = weekdayNames[peakSpendingDayNum]

        let days = snapshot.timeframeDays ?? calculateDaysSinceFirst(transactions: snapshot.transactions)
        let expenses = filtered.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }
        let dailyAverage = days > 0 ? expenses / Double(days) : 0

        let avgTimeBetweenTx = calculateAverageTimeBetweenTransactions(filtered: filtered)

        return SpendingPatterns(
            mostActiveDay: mostActiveDay,
            peakSpendingDay: peakSpendingDay,
            avgTimeBetweenTx: avgTimeBetweenTx,
            dailyAverage: dailyAverage
        )
    }

    // MARK: - Monthly Comparison

    func calculateMonthlyComparison(from filtered: [Transaction]) -> [MonthlyData] {
        let calendar = Calendar.current
        var monthlyData: [String: (income: Double, expenses: Double)] = [:]

        for tx in filtered {
            let monthKey = calendar.dateComponents([.year, .month], from: tx.date)
            let key = "\(monthKey.year ?? 0)-\(String(format: "%02d", monthKey.month ?? 0))"

            var current = monthlyData[key, default: (0, 0)]
            if tx.kind == .income {
                current.income += abs(tx.amount)
            } else {
                current.expenses += abs(tx.amount)
            }
            monthlyData[key] = current
        }

        return monthlyData.compactMap { key, values in
            let components = key.split(separator: "-")
            guard components.count == 2,
                  let year = Int(components[0]),
                  let month = Int(components[1]),
                  let date = calendar.date(from: DateComponents(year: year, month: month)) else {
                return MonthlyData(month: key, income: values.income, expenses: values.expenses, net: values.income - values.expenses)
            }
            return MonthlyData(
                month: Self.monthlyDateFormatter.string(from: date),
                income: values.income,
                expenses: values.expenses,
                net: values.income - values.expenses
            )
        }
        .sorted(by: { $0.month > $1.month })
    }

    // MARK: - Largest Transactions

    func calculateLargestTransactions(from filtered: [Transaction]) -> [TransactionData] {
        filtered
            .sorted(by: { abs($0.amount) > abs($1.amount) })
            .prefix(10)
            .map { TransactionData(
                category: $0.category,
                amount: abs($0.amount),
                date: $0.date,
                isExpense: $0.kind == .expense
            )}
    }

    // MARK: - Spending Velocity

    func calculateSpendingVelocity(
        from filtered: [Transaction],
        balance: Double
    ) -> SpendingVelocity {
        let expenses = filtered.filter { $0.kind == .expense }

        guard !expenses.isEmpty else {
            return .empty
        }

        let sortedDates = expenses.sorted(by: { $0.date < $1.date })
        guard let firstDate = sortedDates.first?.date,
              let lastDate = sortedDates.last?.date else {
            return .empty
        }

        let days = max(1, Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1)
        let totalSpent = expenses.reduce(0) { $0 + abs($1.amount) }
        let rate = totalSpent / Double(days)

        let daysUntilDepletion = rate > 0 ? Int(balance / rate) : 0
        let projectedMonthly = rate * 30

        return SpendingVelocity(
            rate: rate,
            daysUntilDepletion: daysUntilDepletion,
            projectedMonthly: projectedMonthly
        )
    }

    // MARK: - Savings Rate

    func calculateSavingsRate(from filtered: [Transaction]) -> SavingsRate {
        let income = filtered.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        let expenses = filtered.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }
        let saved = max(income - expenses, 0)

        let minDivisor = 0.01
        let rate = income > minDivisor ? (saved / income) * 100 : 0

        return SavingsRate(rate: rate, totalSaved: saved)
    }

    // MARK: - Previous Period Stats

    func calculatePreviousPeriodStats(snapshot: InsightSnapshot) -> InsightStats? {
        guard let days = snapshot.timeframeDays else { return nil }

        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate),
              let previousStartDate = Calendar.current.date(byAdding: .day, value: -days, to: startDate) else {
            return nil
        }

        let previousTransactions = snapshot.transactions.filter {
            $0.date >= previousStartDate && $0.date < startDate
        }

        guard !previousTransactions.isEmpty else { return nil }

        let income = previousTransactions.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        let expenses = previousTransactions.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }

        return InsightStats(
            income: income,
            expenses: expenses,
            net: income - expenses,
            transactionCount: previousTransactions.count,
            incomeCount: previousTransactions.filter { $0.kind == .income }.count,
            expenseCount: previousTransactions.filter { $0.kind == .expense }.count,
            avgTransaction: 0,
            transactionsPerDay: 0,
            topExpenseCategories: [],
            topIncomeCategories: [],
            incomeChange: nil,
            expensesChange: nil,
            netChange: nil
        )
    }

    // MARK: - Card Stats

    func calculateCardStats(
        from filtered: [Transaction],
        snapshot: InsightSnapshot
    ) -> CardStats {
        let cardSpending = filtered
            .filter { $0.kind == .expense && $0.cardId != nil }
            .reduce(0) { $0 + abs($1.amount) }

        var cardsOverLimit = 0
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)

        for card in snapshot.cards {
            if let dailyLimit = card.dailyLimit, dailyLimit > 0 {
                let daySpending = filtered
                    .filter { $0.cardId == card.id && $0.kind == .expense && $0.date >= startOfDay }
                    .reduce(0) { $0 + abs($1.amount) }
                if daySpending > dailyLimit {
                    cardsOverLimit += 1
                }
            }
        }

        let avgSpending = snapshot.cards.count > 0 ? cardSpending / Double(snapshot.cards.count) : nil

        return CardStats(
            totalSpending: cardSpending,
            cardsOverLimit: cardsOverLimit,
            avgSpendingPerCard: avgSpending
        )
    }

    // MARK: - Private Helpers

    private func calculateDaysSinceFirst(transactions: [Transaction]) -> Int {
        guard let first = transactions.first?.date else { return 1 }
        return Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 1
    }

    private func calculateCategoryBreakdowns(
        filtered: [Transaction],
        totalExpenses: Double,
        totalIncome: Double
    ) -> (expense: [(name: String, amount: Double, percentage: Double)],
          income: [(name: String, amount: Double, percentage: Double)]) {
        var categoryTotals: [String: Double] = [:]
        var incomeCategoryTotals: [String: Double] = [:]

        for tx in filtered {
            if tx.kind == .expense {
                categoryTotals[tx.category, default: 0] += abs(tx.amount)
            } else {
                incomeCategoryTotals[tx.category, default: 0] += abs(tx.amount)
            }
        }

        let minDivisor = 0.01
        let expensePercentDivisor = max(totalExpenses, minDivisor)
        let incomePercentDivisor = max(totalIncome, minDivisor)

        let topExpense = categoryTotals
            .sorted(by: { $0.value > $1.value })
            .prefix(10)
            .map { (name: $0.key, amount: $0.value, percentage: ($0.value / expensePercentDivisor) * 100) }

        let topIncome = incomeCategoryTotals
            .sorted(by: { $0.value > $1.value })
            .prefix(10)
            .map { (name: $0.key, amount: $0.value, percentage: ($0.value / incomePercentDivisor) * 100) }

        return (topExpense, topIncome)
    }

    private func calculateAverageTimeBetweenTransactions(filtered: [Transaction]) -> String {
        let sortedDates = filtered.sorted { $0.date < $1.date }
        var totalTimeBetween: TimeInterval = 0
        var timeBetweenCount = 0

        let maxGap: TimeInterval = 86400 * 30

        for i in 1..<sortedDates.count {
            let timeDiff = sortedDates[i].date.timeIntervalSince(sortedDates[i-1].date)
            if timeDiff > 0 && timeDiff < maxGap {
                totalTimeBetween += timeDiff
                timeBetweenCount += 1
            }
        }

        let avgTimeBetween = timeBetweenCount > 0 ? totalTimeBetween / Double(timeBetweenCount) : 0
        let hours = Int(avgTimeBetween / 3600)
        let minutes = Int((avgTimeBetween.truncatingRemainder(dividingBy: 3600)) / 60)

        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
