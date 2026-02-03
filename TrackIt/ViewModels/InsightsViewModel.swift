import SwiftUI
import Combine

@MainActor
class InsightsViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var stats: InsightStats?

    @Published private(set) var spendingPatterns: SpendingPatterns?

    @Published private(set) var monthlyComparison: [MonthlyData] = []

    @Published private(set) var largestTransactions: [TransactionData] = []

    @Published private(set) var cardStats: CardStats?

    @Published private(set) var spendingVelocity: SpendingVelocity?

    @Published private(set) var savingsRate: SavingsRate?

    @Published private(set) var previousStats: InsightStats?

    @Published private(set) var isLoading = false

    @Published private(set) var error: InsightsError?

    // MARK: - Private State

    private var currentTimeframe: InsightTimeFrame?
    private var currentSection: InsightSection?
    private var cachedFilteredTransactions: [Transaction]?
    private var computationTask: Task<Void, Never>?
    private var sectionTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    private let calculator = InsightsCalculator()

    // MARK: - Initialization

    init() {}

    deinit {
        computationTask?.cancel()
        sectionTask?.cancel()
        debounceTask?.cancel()
    }

    // MARK: - Public Interface

    func loadData(
        transactions: [Transaction],
        cards: [CardInfo],
        timeframe: InsightTimeFrame,
        section: InsightSection,
        balance: Double
    ) async {

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: AppConstants.Animation.debounceNanoseconds)
            guard !Task.isCancelled else { return }

            await performLoad(
                transactions: transactions,
                cards: cards,
                timeframe: timeframe,
                section: section,
                balance: balance
            )
        }
    }

    func refresh() async {
        error = nil

        if let snapshot = lastSnapshot {
            await performLoad(
                transactions: snapshot.transactions,
                cards: snapshot.cards,
                timeframe: currentTimeframe ?? .month,
                section: currentSection ?? .overview,
                balance: snapshot.balance
            )
        }
    }

    func cancelAllTasks() {
        computationTask?.cancel()
        sectionTask?.cancel()
        debounceTask?.cancel()
    }

    func clearError() {
        error = nil
    }

    // MARK: - Private State Tracking

    private var lastSnapshot: InsightSnapshot?

    // MARK: - Private Implementation

    private func performLoad(
        transactions: [Transaction],
        cards: [CardInfo],
        timeframe: InsightTimeFrame,
        section: InsightSection,
        balance: Double
    ) async {
        let snapshot = InsightSnapshot(
            transactions: transactions,
            cards: cards,
            timeframeDays: timeframe.days,
            balance: balance,
            selectedSection: section
        )

        lastSnapshot = snapshot


        let needsMainStats = stats == nil || currentTimeframe != timeframe

        if needsMainStats {
            currentTimeframe = timeframe
            await calculateMainStats(snapshot: snapshot)
        }


        if currentSection != section || needsMainStats {
            currentSection = section
            await loadSectionData(snapshot: snapshot)
        }
    }

    private func calculateMainStats(snapshot: InsightSnapshot) async {
        isLoading = true
        error = nil

        let calc = calculator

        computationTask?.cancel()
        computationTask = Task {
            let filtered = calc.filterTransactions(snapshot: snapshot)
            let prevStats = calc.calculatePreviousPeriodStats(snapshot: snapshot)
            let newStats = calc.calculateStats(from: filtered, snapshot: snapshot, previousStats: prevStats)

            guard !Task.isCancelled else { return }

            cachedFilteredTransactions = filtered
            previousStats = prevStats
            stats = newStats
            isLoading = false
        }
    }

    private func loadSectionData(snapshot: InsightSnapshot) async {
        let section = snapshot.selectedSection
        let cachedTransactions = cachedFilteredTransactions
        let calc = calculator
        let hasPreviousStats = previousStats != nil

        sectionTask?.cancel()
        sectionTask = Task {

            try? await Task.sleep(nanoseconds: AppConstants.Animation.sectionLoadDelay)
            guard !Task.isCancelled else { return }

            let filtered = cachedTransactions ?? calc.filterTransactions(snapshot: snapshot)

            switch section {
            case .overview, .categories:

                break

            case .transactions:
                let largest = calc.calculateLargestTransactions(from: filtered)
                let cardStatsResult = calc.calculateCardStats(from: filtered, snapshot: snapshot)
                guard !Task.isCancelled else { return }
                largestTransactions = largest
                cardStats = cardStatsResult

            case .patterns:
                let patternsResult = calc.calculateSpendingPatterns(from: filtered, snapshot: snapshot)
                let monthly = calc.calculateMonthlyComparison(from: filtered)
                guard !Task.isCancelled else { return }
                spendingPatterns = patternsResult
                monthlyComparison = monthly

            case .analysis:
                let velocity = calc.calculateSpendingVelocity(from: filtered, balance: snapshot.balance)
                let savings = calc.calculateSavingsRate(from: filtered)
                let previous = !hasPreviousStats ? calc.calculatePreviousPeriodStats(snapshot: snapshot) : nil
            guard !Task.isCancelled else { return }
                spendingVelocity = velocity
                savingsRate = savings
                if let previous = previous { previousStats = previous }
            }
        }
    }
}
