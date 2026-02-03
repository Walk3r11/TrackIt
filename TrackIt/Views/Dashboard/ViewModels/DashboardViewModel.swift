import SwiftUI
import Combine

@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var totalBalance: Double = 0

    @Published private(set) var averageSpent: String = ""

    @Published private(set) var savedAmount: Double = 0

    @Published private(set) var savingsProgress: Double?

    @Published private(set) var overLimitCardIds: Set<UUID> = []

    @Published private(set) var cachedCardSeries: [UUID: [Double]] = [:]

    @Published private(set) var totalIncome: Double = 0

    @Published private(set) var totalExpenses: Double = 0

    @Published private(set) var isLoading = false

    @Published private(set) var error: DashboardError?

    // MARK: - Private State

    private var seriesTask: Task<Void, Never>?
    private var savedAmountTask: Task<Void, Never>?
    private var cachedPeriod: Period?
    private var cachedTransactionCount: Int = 0

    // MARK: - Initialization

    init() {}

    deinit {
        seriesTask?.cancel()
        savedAmountTask?.cancel()
    }

    // MARK: - Public Interface

    func updateMetrics(
        cards: [CardInfo],
        transactions: [Transaction],
        period: Period,
        savingsGoal: Double,
        savingsPeriod: SpendingLimitPeriod
    ) async {
        isLoading = true
        defer { isLoading = false }


        totalBalance = calculateTotalBalance(cards: cards)

        let (income, expenses) = calculateTotals(transactions: transactions)
        totalIncome = income
        totalExpenses = expenses


        averageSpent = calculateAverageSpent(expenses: expenses, period: period)


        overLimitCardIds = findOverLimitCards(cards: cards, transactions: transactions)


        savedAmount = calculateSavedAmount(transactions: transactions, period: savingsPeriod)

        if savingsGoal > 0 {
            savingsProgress = min(max(savedAmount / savingsGoal, 0), 1)
        } else {
            savingsProgress = nil
        }


        cachedPeriod = period
        cachedTransactionCount = transactions.count
    }

    func updateCardSeries(cards: [CardInfo], transactions: [Transaction]) async {
        seriesTask?.cancel()
        let calc = DashboardCalculator.self
        let cardIds = cards.map { $0.id }

        seriesTask = Task { [weak self] in
            var results: [UUID: [Double]] = [:]

            for cardId in cardIds {
                results[cardId] = calc.calculateDailyNetSeries(
                    transactions: transactions,
                    cardId: cardId,
                    days: 12
                )
            }

            guard !Task.isCancelled else { return }

            self?.cachedCardSeries = results
        }
    }

    func clearError() {
        error = nil
    }

    // MARK: - Private Calculation Methods

    private func calculateTotalBalance(cards: [CardInfo]) -> Double {
        cards.reduce(0) { $0 + ($1.balance ?? 0) }
    }

    private func calculateTotals(transactions: [Transaction]) -> (income: Double, expenses: Double) {
        var income: Double = 0
        var expenses: Double = 0

        for tx in transactions {
            if tx.kind == .income {
                income += abs(tx.amount)
            } else {
                expenses += abs(tx.amount)
            }
        }

        return (income, expenses)
    }

    private func calculateAverageSpent(expenses: Double, period: Period) -> String {
        let days = max(1, period.days)
        let average = expenses / Double(days)
        return average.formattedAsCurrency()
    }

    private func findOverLimitCards(cards: [CardInfo], transactions: [Transaction]) -> Set<UUID> {
        let calendar = Calendar.current
        let now = Date()
        var overLimit: Set<UUID> = []

        for card in cards {
            guard let dailyLimit = card.dailyLimit, dailyLimit > 0 else { continue }

            let startOfDay = calendar.startOfDay(for: now)
            let daySpending = transactions
                .filter { $0.cardId == card.id && $0.kind == .expense && $0.date >= startOfDay }
                .reduce(0) { $0 + abs($1.amount) }

            if daySpending > dailyLimit {
                overLimit.insert(card.id)
            }
        }

        return overLimit
    }

    private func calculateSavedAmount(transactions: [Transaction], period: SpendingLimitPeriod) -> Double {
        DashboardCalculator.savedAmount(for: period, now: .now, transactions: transactions)
    }
}

// MARK: - Dashboard Calculator

enum DashboardCalculator {

    nonisolated static func savedAmount(
        for period: SpendingLimitPeriod,
        now: Date,
        transactions: [Transaction]
    ) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let start = periodStart(for: period, now: now, calendar: calendar)
        var incomeSum: Double = 0
        var expenseSum: Double = 0

        for tx in transactions {
            let txDateStart = calendar.startOfDay(for: tx.date)
            let normalizedStart = calendar.startOfDay(for: start)

            guard txDateStart >= normalizedStart else { continue }

            if tx.kind == .income {
                incomeSum += abs(tx.amount)
            } else {
                expenseSum += abs(tx.amount)
            }
        }
        return max(incomeSum - expenseSum, 0)
    }

    nonisolated static func periodStart(
        for period: SpendingLimitPeriod,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let nowStartOfDay = calendar.startOfDay(for: now)
        switch period {
        case .daily:
            return nowStartOfDay
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: nowStartOfDay)?.start ?? nowStartOfDay
        case .monthly:
            return calendar.dateInterval(of: .month, for: nowStartOfDay)?.start ?? nowStartOfDay
        }
    }

    nonisolated static func calculateDailyNetSeries(
        transactions: [Transaction],
        cardId: UUID,
        days: Int
    ) -> [Double] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else {
            return []
        }

        var dailyAmounts = Array(repeating: 0.0, count: days)

        for tx in transactions where (tx.cardId == nil || tx.cardId == cardId) && tx.date >= start {
            let txDay = calendar.startOfDay(for: tx.date)
            if let dayIndex = calendar.dateComponents([.day], from: start, to: txDay).day,
               dayIndex >= 0 && dayIndex < days {
                dailyAmounts[dayIndex] += tx.amount
            }
        }

        var running: Double = 0
        return dailyAmounts.map { amount in
            running += amount
            return running
        }
    }
}

// MARK: - Dashboard Error

enum DashboardError: LocalizedError {
    case calculationFailed(Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .calculationFailed(let error):
            return "Failed to calculate dashboard metrics: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data provided to dashboard"
        }
    }
}

// MARK: - Period Extension

extension Period {
    var days: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .quarterly: return 90
        case .semiannual: return 182
        case .nineMonth: return 273
        case .yearly: return 365
        }
    }
}
