import SwiftUI

struct InsightsTab: View {
    @EnvironmentObject private var session: SessionManager
    @Binding var transactions: [Transaction]
    @Binding var cards: [CardInfo]
    @Binding var selectedPeriod: Period
    
    @State private var selectedTimeframe: TimeFrame = .month
    @State private var selectedSection: InsightSection = .overview
    @State private var cachedStats: InsightStats?
    @State private var cachedTimeframe: TimeFrame?
    @State private var cachedSpendingPatterns: SpendingPatterns?
    @State private var cachedMonthlyComparison: [MonthlyData]?
    @State private var cachedLargestTransactions: [TransactionData]?
    @State private var cachedSpendingVelocity: SpendingVelocity?
    @State private var cachedSavingsRate: SavingsRate?
    @State private var cachedCardStats: CardStats?
    @State private var cachedPreviousStats: InsightStats?
    @State private var cachedFilteredTransactions: [Transaction]?
    
    enum InsightSection: String, CaseIterable {
        case overview = "Overview"
        case categories = "Categories"
        case transactions = "Transactions"
        case patterns = "Patterns"
        case analysis = "Analysis"
        
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
    
    enum TimeFrame: String, CaseIterable {
        case week = "Past Week"
        case month = "Past Month"
        case quarter = "Past 3 Months"
        case year = "Past Year"
        case all = "All Time"
        
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
    
    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                combinedSelectors
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                
                TabView(selection: $selectedSection) {
                    overviewTab
                        .tag(InsightSection.overview)
                    
                    categoriesTab
                        .tag(InsightSection.categories)
                    
                    transactionsTab
                        .tag(InsightSection.transactions)
                    
                    patternsTab
                        .tag(InsightSection.patterns)
                    
                    analysisTab
                        .tag(InsightSection.analysis)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedSection)
            }
            .onChange(of: selectedTimeframe) { _, _ in
                cachedStats = nil
                cachedTimeframe = nil
                cachedSpendingPatterns = nil
                cachedMonthlyComparison = nil
                cachedLargestTransactions = nil
                cachedSpendingVelocity = nil
                cachedSavingsRate = nil
                cachedCardStats = nil
                cachedPreviousStats = nil
                cachedFilteredTransactions = nil
            }
            .task(id: selectedTimeframe) {
                if cachedStats == nil || cachedTimeframe != selectedTimeframe {
                    await calculateAllStats()
                }
            }
            .onChange(of: selectedSection) { _, newSection in
                Task {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    await loadSectionData()
                }
            }
        }
    }
    
    private var combinedSelectors: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(InsightSection.allCases, id: \.self) { section in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSection = section
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(section.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(selectedSection == section ? .white : Palette.primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    selectedSection == section
                                        ? LinearGradient(colors: [Palette.accentAlt, Palette.accent], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Palette.card, Palette.cardAlt], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedSection == section ? Color.clear : Palette.stroke, lineWidth: 1)
                                )
                                .shadow(
                                    color: selectedSection == section ? Palette.accent.opacity(0.18) : Color.clear,
                                    radius: selectedSection == section ? 8 : 0,
                                    x: 0,
                                    y: selectedSection == section ? 4 : 0
                                )
                            }
                            .id(section)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 4)
                .background(
                    LinearGradient(
                        colors: [Palette.card.opacity(0.6), Palette.cardAlt.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Palette.stroke.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: selectedSection) { _, newSection in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newSection, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedSection, anchor: .center)
                }
            }
            .padding(.horizontal, 4)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTimeframe = timeframe
                                }
                            } label: {
                                Text(timeframe.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(selectedTimeframe == timeframe ? .white : Palette.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedTimeframe == timeframe
                                            ? LinearGradient(colors: [Palette.accentAlt, Palette.accent], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [Palette.card, Palette.cardAlt], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedTimeframe == timeframe ? Color.clear : Palette.stroke.opacity(0.5), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: selectedTimeframe == timeframe ? Palette.accent.opacity(0.15) : Color.clear,
                                        radius: selectedTimeframe == timeframe ? 5 : 0,
                                        x: 0,
                                        y: selectedTimeframe == timeframe ? 2 : 0
                                    )
                            }
                            .id(timeframe)
                        }
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                }
                .onChange(of: selectedTimeframe) { _, newTimeframe in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newTimeframe, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedTimeframe, anchor: .center)
                }
            }
        }
    }
    
    @ViewBuilder
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                overviewSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private var categoriesTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                categoryBreakdownSection
                incomeBreakdownSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private var transactionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                transactionStatsSection
                cardStatsSection
                largestTransactionsSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private var patternsTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                spendingPatternsSection
                monthlyComparisonSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private var analysisTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                spendingVelocitySection
                savingsRateSection
                trendsSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    private var overviewSection: some View {
        InsightsSection(title: "Overview", icon: "chart.bar.fill") {
            let stats = getCachedStats()
            
            VStack(spacing: 16) {
                StatCard(
                    title: "Total Income",
                    value: stats.income.formatted(.currency(code: "EUR")),
                    icon: "arrow.down.circle.fill",
                    color: Palette.success,
                    change: stats.incomeChange
                )
                
                StatCard(
                    title: "Total Expenses",
                    value: stats.expenses.formatted(.currency(code: "EUR")),
                    icon: "arrow.up.circle.fill",
                    color: Palette.danger,
                    change: stats.expensesChange
                )
                
                StatCard(
                    title: "Net Balance",
                    value: stats.net.formatted(.currency(code: "EUR")),
                    icon: "equal.circle.fill",
                    color: stats.net >= 0 ? Palette.success : Palette.danger,
                    change: stats.netChange
                )
            }
        }
    }
    
    private var categoryBreakdownSection: some View {
        InsightsSection(title: "Top Spending Categories", icon: "tag.fill") {
            let stats = getCachedStats()
            let topCategories = stats.topExpenseCategories
            
            if topCategories.isEmpty {
                Text("No spending data available")
                    .font(.subheadline)
                    .foregroundColor(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topCategories.prefix(6).enumerated()), id: \.offset) { index, category in
                        CategoryStatRow(
                            rank: index + 1,
                            category: category.name,
                            amount: category.amount,
                            percentage: category.percentage,
                            color: CategoryColors.color(for: category.name)
                        )
                    }
                }
            }
        }
    }
    
    private var incomeBreakdownSection: some View {
        InsightsSection(title: "Income Sources", icon: "arrow.down.circle.fill") {
            let stats = getCachedStats()
            let incomeCategories = stats.topIncomeCategories
            
            if incomeCategories.isEmpty {
                Text("No income data available")
                    .font(.subheadline)
                    .foregroundColor(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(incomeCategories.prefix(6).enumerated()), id: \.offset) { index, category in
                        CategoryStatRow(
                            rank: index + 1,
                            category: category.name,
                            amount: category.amount,
                            percentage: category.percentage,
                            color: Palette.success
                        )
                    }
                }
            }
        }
    }
    
    private var spendingPatternsSection: some View {
        InsightsSection(title: "Spending Patterns", icon: "clock.fill") {
            let stats = cachedSpendingPatterns ?? SpendingPatterns(mostActiveDay: "N/A", peakSpendingDay: "N/A", avgTimeBetweenTx: "N/A", dailyAverage: 0)
            
            VStack(spacing: 16) {
                StatRow(
                    icon: "calendar.badge.clock",
                    title: "Most Active Day",
                    value: stats.mostActiveDay,
                    iconColor: Palette.accent
                )
                
                StatRow(
                    icon: "calendar.badge.exclamationmark",
                    title: "Peak Spending Day",
                    value: stats.peakSpendingDay,
                    iconColor: Palette.danger
                )
                
                StatRow(
                    icon: "hourglass",
                    title: "Average Time Between Transactions",
                    value: stats.avgTimeBetweenTx,
                    iconColor: Palette.warning
                )
                
                StatRow(
                    icon: "chart.bar.fill",
                    title: "Daily Average Spending",
                    value: stats.dailyAverage.formatted(.currency(code: "EUR")),
                    iconColor: Palette.accentAlt
                )
            }
        }
    }
    
    private var monthlyComparisonSection: some View {
        InsightsSection(title: "Monthly Comparison", icon: "calendar") {
            let comparison = cachedMonthlyComparison ?? []
            
            if comparison.isEmpty {
                Text("Insufficient data for monthly comparison")
                    .font(.subheadline)
                    .foregroundColor(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(comparison.prefix(6).enumerated()), id: \.offset) { index, month in
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
    
    private var largestTransactionsSection: some View {
        InsightsSection(title: "Largest Transactions", icon: "arrow.up.circle.fill") {
            let largest = cachedLargestTransactions ?? []
            
            if largest.isEmpty {
                Text("No transaction data available")
                    .font(.subheadline)
                    .foregroundColor(Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(largest.prefix(6).enumerated()), id: \.offset) { index, tx in
                        TransactionRow(
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
    
    private var spendingVelocitySection: some View {
        InsightsSection(title: "Spending Velocity", icon: "speedometer") {
            let velocity = cachedSpendingVelocity ?? SpendingVelocity(rate: 0, daysUntilDepletion: 0, projectedMonthly: 0)
            
            VStack(spacing: 16) {
                StatRow(
                    icon: "gauge.high",
                    title: "Spending Rate",
                    value: velocity.rate.formatted(.currency(code: "EUR")) + "/day",
                    iconColor: Palette.danger
                )
                
                StatRow(
                    icon: "clock.arrow.circlepath",
                    title: "Days Until Budget Depletion",
                    value: velocity.daysUntilDepletion > 0 ? "\(velocity.daysUntilDepletion)" : "N/A",
                    iconColor: Palette.warning
                )
                
                StatRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Projected Monthly Spending",
                    value: velocity.projectedMonthly.formatted(.currency(code: "EUR")),
                    iconColor: Palette.accentAlt
                )
            }
        }
    }
    
    private var savingsRateSection: some View {
        InsightsSection(title: "Savings Analysis", icon: "banknote.fill") {
            let savings = cachedSavingsRate ?? SavingsRate(rate: 0, totalSaved: 0)
            
            VStack(spacing: 16) {
                StatCard(
                    title: "Savings Rate",
                    value: String(format: "%.1f%%", savings.rate),
                    icon: "percent.circle.fill",
                    color: savings.rate >= 20 ? Palette.success : Palette.warning,
                    change: nil
                )
                
                StatRow(
                    icon: "arrow.down.circle.fill",
                    title: "Total Saved",
                    value: savings.totalSaved.formatted(.currency(code: "EUR")),
                    iconColor: Palette.success
                )
                
                StatRow(
                    icon: "target",
                    title: "Recommended Savings Rate",
                    value: "20%",
                    iconColor: Palette.accent
                )
                
                if savings.rate < 20 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Palette.warning)
                        Text("Consider increasing your savings rate to 20% or more")
                            .font(.caption)
                            .foregroundColor(Palette.secondary)
                    }
                    .padding(12)
                    .background(Palette.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    private var transactionStatsSection: some View {
        InsightsSection(title: "Transaction Statistics", icon: "list.bullet.rectangle.fill") {
            let stats = getCachedStats()
            
            VStack(spacing: 16) {
                StatRow(
                    icon: "number.circle.fill",
                    title: "Total Transactions",
                    value: "\(stats.transactionCount)",
                    iconColor: Palette.accent
                )
                
                StatRow(
                    icon: "eurosign.circle.fill",
                    title: "Average Transaction",
                    value: stats.avgTransaction.formatted(.currency(code: "EUR")),
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
            }
        }
    }
    
    private var cardStatsSection: some View {
        InsightsSection(title: "Card Statistics", icon: "creditcard.fill") {
            let stats = cachedCardStats ?? CardStats(totalSpending: 0, cardsOverLimit: 0, avgSpendingPerCard: nil)
            
            VStack(spacing: 16) {
                StatRow(
                    icon: "creditcard.circle.fill",
                    title: "Total Cards",
                    value: "\(cards.count)",
                    iconColor: Palette.accent
                )
                
                StatRow(
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    title: "Total Spending",
                    value: stats.totalSpending.formatted(.currency(code: "EUR")),
                    iconColor: Palette.danger
                )
                
                StatRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Cards Over Limit",
                    value: "\(stats.cardsOverLimit)",
                    iconColor: Palette.warning
                )
                
                if let avgSpending = stats.avgSpendingPerCard {
                    StatRow(
                        icon: "equal.circle.fill",
                        title: "Avg per Card",
                        value: avgSpending.formatted(.currency(code: "EUR")),
                        iconColor: Palette.accentAlt
                    )
                }
            }
        }
    }
    
    private var trendsSection: some View {
        InsightsSection(title: "Trends", icon: "chart.line.uptrend.xyaxis") {
            let stats = getCachedStats()
            
            VStack(spacing: 16) {
                if let previousStats = cachedPreviousStats {
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
                    Text("Insufficient data for trend analysis")
                        .font(.subheadline)
                        .foregroundColor(Palette.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
    }
    
    @MainActor
    private func calculateAllStats() async {
        let filtered = filterTransactions()
        cachedFilteredTransactions = filtered
        
        cachedStats = calculateStats(from: filtered)
        cachedTimeframe = selectedTimeframe
    }
    
    @MainActor
    private func loadSectionData() async {
        guard let filtered = cachedFilteredTransactions else { return }
        
        Task { @MainActor in
            switch selectedSection {
            case .patterns:
                if cachedSpendingPatterns == nil {
                    cachedSpendingPatterns = calculateSpendingPatterns(from: filtered)
                }
                if cachedMonthlyComparison == nil {
                    cachedMonthlyComparison = calculateMonthlyComparison(from: filtered)
                }
            case .transactions:
                if cachedLargestTransactions == nil {
                    cachedLargestTransactions = calculateLargestTransactions(from: filtered)
                }
                if cachedCardStats == nil {
                    cachedCardStats = calculateCardStats(from: filtered)
                }
            case .analysis:
                if cachedSpendingVelocity == nil {
                    cachedSpendingVelocity = calculateSpendingVelocity(from: filtered)
                }
                if cachedSavingsRate == nil {
                    cachedSavingsRate = calculateSavingsRate(from: filtered)
                }
                if cachedPreviousStats == nil {
                    cachedPreviousStats = calculatePreviousPeriodStats()
                }
            case .categories:
                if cachedStats == nil {
                    cachedStats = calculateStats(from: filtered)
                }
            default:
                break
            }
        }
    }
    
    private func getCachedStats() -> InsightStats {
        if let cached = cachedStats, cachedTimeframe == selectedTimeframe {
            return cached
        }
        let filtered = filterTransactions()
        let stats = calculateStats(from: filtered)
        Task { @MainActor in
            cachedStats = stats
            cachedTimeframe = selectedTimeframe
        }
        return stats
    }
    
    private func filterTransactions() -> [Transaction] {
        if let cached = cachedFilteredTransactions, cachedTimeframe == selectedTimeframe {
            return cached
        }
        guard let days = selectedTimeframe.days else {
            return transactions
        }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filtered = transactions.filter { $0.date >= cutoffDate }
        Task { @MainActor in
            cachedFilteredTransactions = filtered
        }
        return filtered
    }
    
    private func calculateStats(from filtered: [Transaction]) -> InsightStats {
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
        
        let days = selectedTimeframe.days ?? {
            if let first = transactions.first?.date {
                return Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 1
            }
            return 1
        }()
        let transactionsPerDay = days > 0 ? Double(totalCount) / Double(days) : 0
        
        var categoryTotals: [String: Double] = [:]
        var incomeCategoryTotals: [String: Double] = [:]
        
        for tx in filtered {
            if tx.kind == .expense {
                categoryTotals[tx.category, default: 0] += abs(tx.amount)
            } else {
                incomeCategoryTotals[tx.category, default: 0] += abs(tx.amount)
            }
        }
        
        let totalExpenses = expenses
        let totalIncome = income
        let expensePercentDivisor = totalExpenses > 0 ? totalExpenses : 1
        let incomePercentDivisor = totalIncome > 0 ? totalIncome : 1
        
        let topExpenseCategories = categoryTotals
            .sorted(by: { $0.value > $1.value })
            .prefix(10)
            .map { (name: $0.key, amount: $0.value, percentage: ($0.value / expensePercentDivisor) * 100) }
        
        let topIncomeCategories = incomeCategoryTotals
            .sorted(by: { $0.value > $1.value })
            .prefix(10)
            .map { (name: $0.key, amount: $0.value, percentage: ($0.value / incomePercentDivisor) * 100) }
        
        let previousStats = cachedPreviousStats
        let incomeChange = previousStats.map { ((income - $0.income) / max($0.income, 1)) * 100 }
        let expensesChange = previousStats.map { ((expenses - $0.expenses) / max($0.expenses, 1)) * 100 }
        let netChange = previousStats.map { ((net - $0.net) / max(abs($0.net), 1)) * 100 }
        
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
    
    private func calculateSpendingPatterns(from filtered: [Transaction]) -> SpendingPatterns {
        let calendar = Calendar.current
        
        var dayOfWeekSpending: [Int: (count: Int, amount: Double)] = [:]
        var dayOfWeekCounts: [Int: Int] = [:]
        
        for tx in filtered where tx.kind == .expense {
            let weekday = calendar.component(.weekday, from: tx.date)
            dayOfWeekSpending[weekday, default: (0, 0)].amount += abs(tx.amount)
            dayOfWeekSpending[weekday, default: (0, 0)].count += 1
            dayOfWeekCounts[weekday, default: 0] += 1
        }
        
        let mostActiveDayNum = dayOfWeekCounts.max(by: { $0.value < $1.value })?.key ?? 1
        let peakSpendingDayNum = dayOfWeekSpending.max(by: { $0.value.amount < $1.value.amount })?.key ?? 1
        
        let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let mostActiveDay = weekdayNames[mostActiveDayNum]
        let peakSpendingDay = weekdayNames[peakSpendingDayNum]
        
        let days = selectedTimeframe.days ?? {
            if let first = transactions.first?.date {
                return Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 1
            }
            return 1
        }()
        
        let expenses = filtered.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }
        let dailyAverage = days > 0 ? expenses / Double(days) : 0
        
        let sortedDates = filtered.sorted { $0.date < $1.date }
        var totalTimeBetween: TimeInterval = 0
        var timeBetweenCount = 0
        let maxTimeDiff: TimeInterval = 86400 * 30
        
        for i in 1..<sortedDates.count {
            let timeDiff = sortedDates[i].date.timeIntervalSince(sortedDates[i-1].date)
            if timeDiff > 0 && timeDiff < maxTimeDiff {
                totalTimeBetween += timeDiff
                timeBetweenCount += 1
            }
        }
        
        let avgTimeBetween = timeBetweenCount > 0 ? totalTimeBetween / Double(timeBetweenCount) : 0
        let hours = Int(avgTimeBetween / 3600)
        let minutes = Int((avgTimeBetween.truncatingRemainder(dividingBy: 3600)) / 60)
        let avgTimeBetweenTx = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        
        return SpendingPatterns(
            mostActiveDay: mostActiveDay,
            peakSpendingDay: peakSpendingDay,
            avgTimeBetweenTx: avgTimeBetweenTx,
            dailyAverage: dailyAverage
        )
    }
    
    private static let monthlyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private func calculateMonthlyComparison(from filtered: [Transaction]) -> [MonthlyData] {
        let calendar = Calendar.current
        
        var monthlyData: [String: (income: Double, expenses: Double)] = [:]
        
        for tx in filtered {
            let monthKey = calendar.dateComponents([.year, .month], from: tx.date)
            let key = "\(monthKey.year ?? 0)-\(String(format: "%02d", monthKey.month ?? 0))"
            
            if tx.kind == .income {
                monthlyData[key, default: (0, 0)].income += abs(tx.amount)
            } else {
                monthlyData[key, default: (0, 0)].expenses += abs(tx.amount)
            }
        }
        
        return monthlyData.map { key, values in
            let components = key.split(separator: "-")
            if components.count == 2,
               let year = Int(components[0]),
               let month = Int(components[1]),
               let date = calendar.date(from: DateComponents(year: year, month: month)) {
                return MonthlyData(
                    month: Self.monthlyDateFormatter.string(from: date),
                    income: values.income,
                    expenses: values.expenses,
                    net: values.income - values.expenses
                )
            }
            return MonthlyData(month: key, income: values.income, expenses: values.expenses, net: values.income - values.expenses)
        }
        .sorted(by: { $0.month > $1.month })
    }
    
    private func calculateLargestTransactions(from filtered: [Transaction]) -> [TransactionData] {
        return filtered
            .sorted(by: { abs($0.amount) > abs($1.amount) })
            .prefix(10)
            .map { TransactionData(
                category: $0.category,
                amount: abs($0.amount),
                date: $0.date,
                isExpense: $0.kind == .expense
            )}
    }
    
    private func calculateSpendingVelocity(from filtered: [Transaction]) -> SpendingVelocity {
        let expenses = filtered.filter { $0.kind == .expense }
        
        guard !expenses.isEmpty else {
            return SpendingVelocity(rate: 0, daysUntilDepletion: 0, projectedMonthly: 0)
        }
        
        let sortedDates = expenses.sorted(by: { $0.date < $1.date })
        guard let firstDate = sortedDates.first?.date,
              let lastDate = sortedDates.last?.date else {
            return SpendingVelocity(rate: 0, daysUntilDepletion: 0, projectedMonthly: 0)
        }
        
        let days = max(1, Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1)
        let totalSpent = expenses.reduce(0) { $0 + abs($1.amount) }
        let rate = totalSpent / Double(days)
        
        let currentBalance = session.user?.balance ?? 0
        let daysUntilDepletion = rate > 0 ? Int(currentBalance / rate) : 0
        
        let projectedMonthly = rate * 30
        
        return SpendingVelocity(
            rate: rate,
            daysUntilDepletion: daysUntilDepletion,
            projectedMonthly: projectedMonthly
        )
    }
    
    private func calculateSavingsRate(from filtered: [Transaction]) -> SavingsRate {
        let income = filtered.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        let expenses = filtered.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }
        let saved = max(income - expenses, 0)
        
        let rate = income > 0 ? (saved / income) * 100 : 0
        
        return SavingsRate(
            rate: rate,
            totalSaved: saved
        )
    }
    
    private func calculatePreviousPeriodStats() -> InsightStats? {
        guard let days = selectedTimeframe.days else { return nil }
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let previousStartDate = Calendar.current.date(byAdding: .day, value: -days, to: startDate) ?? startDate
        
        let previousTransactions = transactions.filter {
            $0.date >= previousStartDate && $0.date < startDate
        }
        
        guard !previousTransactions.isEmpty else { return nil }
        
        let income = previousTransactions.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        let expenses = previousTransactions.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }
        let net = income - expenses
        
        return InsightStats(
            income: income,
            expenses: expenses,
            net: net,
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
    
    private func calculateCardStats(from filtered: [Transaction]) -> CardStats {
        let cardSpending = filtered.filter { $0.kind == .expense && $0.cardId != nil }
            .reduce(0) { $0 + abs($1.amount) }
        
        var cardsOverLimit = 0
        let now = Date()
        let calendar = Calendar.current
        
        for card in cards {
            if let dailyLimit = card.dailyLimit, dailyLimit > 0 {
                let startOfDay = calendar.startOfDay(for: now)
                let daySpending = filtered
                    .filter { $0.cardId == card.id && $0.kind == .expense && $0.date >= startOfDay }
                    .reduce(0) { $0 + abs($1.amount) }
                if daySpending > dailyLimit {
                    cardsOverLimit += 1
                }
            }
        }
        
        let avgSpending = cards.count > 0 ? cardSpending / Double(cards.count) : nil
        
        return CardStats(
            totalSpending: cardSpending,
            cardsOverLimit: cardsOverLimit,
            avgSpendingPerCard: avgSpending
        )
    }
}

private struct InsightStats {
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
}

private struct SpendingPatterns {
    let mostActiveDay: String
    let peakSpendingDay: String
    let avgTimeBetweenTx: String
    let dailyAverage: Double
}

private struct MonthlyData {
    let month: String
    let income: Double
    let expenses: Double
    let net: Double
}

private struct TransactionData {
    let category: String
    let amount: Double
    let date: Date
    let isExpense: Bool
}

private struct SpendingVelocity {
    let rate: Double
    let daysUntilDepletion: Int
    let projectedMonthly: Double
}

private struct SavingsRate {
    let rate: Double
    let totalSaved: Double
}

private struct CardStats {
    let totalSpending: Double
    let cardsOverLimit: Int
    let avgSpendingPerCard: Double?
}

private struct InsightsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let glowColor = Palette.accent
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Palette.accent)
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(Palette.primary)
            }
            
            content
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Palette.card, Palette.cardAlt],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: shape
        )
        .overlay(
            shape.stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: glowColor.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let change: Double?
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.15), in: Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(Palette.primary)
                
                if let change = change {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(change >= 0 ? Palette.success : Palette.danger)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Palette.cardAlt.opacity(0.5), Palette.card.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .shadow(color: color.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

private struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15), in: Circle())
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Palette.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Palette.accent)
        }
        .padding(.vertical, 12)
    }
}

private struct CategoryStatRow: View {
    let rank: Int
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .foregroundColor(Palette.secondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Palette.mutedFill)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(percentage / 100, 1), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount.formatted(.currency(code: "EUR")))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Palette.primary)
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Palette.cardAlt.opacity(0.5), Palette.card.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .shadow(color: color.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

private struct TrendRow: View {
    let title: String
    let current: Double
    let previous: Double
    let icon: String
    let color: Color
    
    private var change: Double {
        guard previous != 0 else { return 0 }
        return ((current - previous) / abs(previous)) * 100
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
                
                HStack(spacing: 8) {
                    Text("Current: \(current.formatted(.currency(code: "EUR")))")
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                    Text("Previous: \(previous.formatted(.currency(code: "EUR")))")
                        .font(.caption)
                        .foregroundColor(Palette.secondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption.weight(.bold))
                    Text(String(format: "%.1f%%", abs(change)))
                        .font(.subheadline.weight(.bold))
                }
                .foregroundColor(change >= 0 ? Palette.success : Palette.danger)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Palette.cardAlt.opacity(0.5), Palette.card.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .shadow(color: color.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

private struct MonthlyComparisonRow: View {
    let month: String
    let income: Double
    let expenses: Double
    let net: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(month)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Palette.primary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Income")
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                    Text(income.formatted(.currency(code: "EUR")))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.success)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expenses")
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                    Text(expenses.formatted(.currency(code: "EUR")))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.danger)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Net")
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                    Text(net.formatted(.currency(code: "EUR")))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(net >= 0 ? Palette.success : Palette.danger)
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Palette.cardAlt.opacity(0.5), Palette.card.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .shadow(color: Palette.accent.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

private struct TransactionRow: View {
    let rank: Int
    let category: String
    let amount: Double
    let date: Date
    let isExpense: Bool
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .foregroundColor(Palette.secondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
                Text(Self.dateFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
            }
            
            Spacer()
            
            Text(amount.formatted(.currency(code: "EUR")))
                .font(.subheadline.weight(.bold))
                .foregroundColor(isExpense ? Palette.danger : Palette.success)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Palette.cardAlt.opacity(0.5), Palette.card.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .shadow(color: (isExpense ? Palette.danger : Palette.success).opacity(0.08), radius: 6, x: 0, y: 3)
    }
}
