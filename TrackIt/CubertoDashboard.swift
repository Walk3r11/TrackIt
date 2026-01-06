import SwiftUI

struct CubertoDashboardLayout: View {
    var userId: String?
    var firstName: String
    @Binding var selectedPeriod: Period

    var totalBalance: Double
    var income: Double
    var expenses: Double
    var cards: [CardInfo]
    @Binding var selectedCardIndex: Int
    var transactions: [Transaction]
    var incomeCategoryBreakdown: [String: Double]
    var expenseCategoryBreakdown: [String: Double]
    var overLimitCardIds: Set<UUID> = []

    var onAddTransaction: () -> Void
    var onViewAllTransactions: () -> Void
    var onAddCard: () -> Void
    var onOpenCards: () -> Void

    private let currencyCode = "EUR"
    @AppStorage("showSavingsCard") private var showSavingsCard = false
    @AppStorage("savingsGoalAmount") private var savingsGoalAmount: Double = 0
    @AppStorage("savingsSavedAmount") private var savingsSavedAmount: Double = 0
    @AppStorage("savingsGoalPeriod") private var savingsGoalPeriodRaw: String = SpendingLimitPeriod.monthly.rawValue
    @State private var showSavingsGoalSheet = false
    @State private var summaryIndex = 0
    @State private var suppressSavingsSync = false
    private let smallCardHeight: CGFloat = 200
    private let summaryCardHeight: CGFloat = 162

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                CubertoHeader(firstName: firstName, periodTitle: selectedPeriod.title, onAdd: onAddTransaction)

                SummaryCardPager(
                    selectedIndex: $summaryIndex,
                    dashboardPeriodTitle: selectedPeriod.title,
                    totalBalanceText: totalBalance.formatted(.currency(code: currencyCode)),
                    cardsCount: cards.count,
                    averageSpentText: averageSpentText,
                    savedAmount: savingsSavedAmount,
                    savedText: savingsSavedAmount.formatted(.currency(code: currencyCode)),
                    savingsPeriodTitle: goalPeriod.title,
                    goalAmount: savingsGoalAmount,
                    goalAmountText: savingsGoalAmount.formatted(.currency(code: currencyCode)),
                    goalProgress: savingsGoalAmount > 0 ? min(max((savingsSavedAmount / savingsGoalAmount), 0), 1) : nil,
                    showSavings: showSavingsCard,
                    onOpenSavings: { showSavingsGoalSheet = true },
                    onAddSavings: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            showSavingsCard = true
                        }
                        showSavingsGoalSheet = true
                    },
                    onRemoveSavings: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            showSavingsCard = false
                        }
                    }
                )
                .padding(.top, 4)
                .padding(.bottom, 6)
                .padding(.horizontal, -LayoutMetrics.horizontalPadding)

                WalletCardPager(
                    cards: cards,
                    selectedCardIndex: $selectedCardIndex,
                    transactions: transactions,
                    overLimitCardIds: overLimitCardIds,
                    onAddCard: onAddCard,
                    onOpenCards: onOpenCards
                )
                .padding(.top, 2)

                PeriodPicker(selectedPeriod: $selectedPeriod)

                SnapshotCard(
                    title: "Spending Overview",
                    subtitle: selectedPeriod.title,
                    income: income,
                    expenses: expenses,
                    incomeCategoryBreakdown: incomeCategoryBreakdown,
                    expenseCategoryBreakdown: expenseCategoryBreakdown
                )
                .padding(.top, 10)

                QuickActionsCard(
                    onAdd: onAddTransaction,
                    onAddCard: onAddCard,
                    showAddSavings: false,
                    onAddSavings: {}
                )
                .frame(height: smallCardHeight)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .padding(.top, 10)

                RecentTransactionsCard(
                    transactions: Array(transactions.prefix(5)),
                    onViewAll: onViewAllTransactions,
                    onAdd: onAddTransaction
                )
                .padding(.top, 10)
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showSavingsGoalSheet) {
            SavingsGoalSheet(
                goalAmount: $savingsGoalAmount,
                goalPeriodRaw: $savingsGoalPeriodRaw,
                currentSaved: savingsSavedAmount
            )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            updateSavedAmountCacheSync()
            savingsSavedAmount = cachedSavedAmount
        }
        .task(id: userId ?? "") {
            guard let userId else { return }
            do {
                let remote = try await APIClient.shared.fetchSavingsGoal(userId: userId)
                await MainActor.run {
                    suppressSavingsSync = true
                    savingsGoalAmount = remote.goalAmount
                    savingsGoalPeriodRaw = remote.goalPeriod.rawValue
                    suppressSavingsSync = false
                    updateSavedAmountCacheSync()
                    savingsSavedAmount = cachedSavedAmount
                }
            } catch {
                await MainActor.run {
                    suppressSavingsSync = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SavingsGoalUpdated"))) { notification in
            if let userInfo = notification.userInfo,
               let goalAmount = userInfo["goalAmount"] as? Double,
               let goalPeriodRaw = userInfo["goalPeriod"] as? String {
                Task { @MainActor in
                    suppressSavingsSync = true
                    savingsGoalAmount = goalAmount
                    savingsGoalPeriodRaw = goalPeriodRaw
                    if goalAmount > 0 {
                        showSavingsCard = true
                    }
                    suppressSavingsSync = false
                    updateSavedAmountCacheSync()
                    savingsSavedAmount = cachedSavedAmount
                }
            }
        }
        .onChange(of: transactions.count) { _, _ in
            DispatchQueue.main.async { [self] in
                updateSavedAmountCacheSync()
                savingsSavedAmount = cachedSavedAmount
            }
        }
        .onChange(of: savingsGoalPeriodRaw) { _, _ in
            DispatchQueue.main.async { [self] in
                updateSavedAmountCacheSync()
                savingsSavedAmount = cachedSavedAmount
            }
            guard !suppressSavingsSync, let userId else { return }
            Task {
                try? await APIClient.shared.updateSavingsGoal(userId: userId, goalAmount: savingsGoalAmount, goalPeriod: goalPeriod)
            }
        }
        .onChange(of: savingsGoalAmount) { _, newValue in
            guard !suppressSavingsSync, let userId else { return }
            Task {
                try? await APIClient.shared.updateSavingsGoal(userId: userId, goalAmount: newValue, goalPeriod: goalPeriod)
            }
        }
        .onChange(of: showSavingsCard) { _, enabled in
            if !enabled && summaryIndex == 1 {
                summaryIndex = 0
            }
        }
    }

    @State private var cachedSavedAmount: Double = 0
    @State private var cachedSavedPeriod: SpendingLimitPeriod = .monthly
    @State private var cachedSavedTransactionCount: Int = 0

    private var goalPeriod: SpendingLimitPeriod {
        SpendingLimitPeriod(rawValue: savingsGoalPeriodRaw) ?? .monthly
    }

    private var currentSavedForGoal: Double {
        return cachedSavedAmount
    }
    
    private func updateSavedAmountCache() {
        DispatchQueue.main.async { [self] in
            updateSavedAmountCacheSync()
        }
    }
    
    private func updateSavedAmountCacheSync() {
        let period = goalPeriod
        let needsUpdate = cachedSavedPeriod != period || 
                         cachedSavedTransactionCount != transactions.count
        
        guard needsUpdate else { return }
        
        cachedSavedAmount = savedAmount(for: period, now: .now)
        cachedSavedPeriod = period
        cachedSavedTransactionCount = transactions.count
    }

    @State private var cachedAverageSpent: String = ""
    @State private var cachedAverageSpentPeriod: Period?
    
    private var averageSpentText: String {
        if cachedAverageSpentPeriod == selectedPeriod && !cachedAverageSpent.isEmpty {
            return cachedAverageSpent
        }
        let days = max(1, selectedPeriodDays(selectedPeriod))
        let avg = expenses / Double(days)
        let formatted = avg.formatted(.currency(code: currencyCode))
        Task { @MainActor in
            cachedAverageSpent = formatted
            cachedAverageSpentPeriod = selectedPeriod
        }
        return formatted
    }

    private func selectedPeriodDays(_ period: Period) -> Int {
        switch period {
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

    private func savedAmount(for period: SpendingLimitPeriod, now: Date) -> Double {
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

    private func periodStart(for period: SpendingLimitPeriod, now: Date, calendar: Calendar) -> Date {
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
}

private struct CubertoHeader: View {
    var firstName: String
    var periodTitle: String
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(text: firstName)

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back!")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Palette.secondary)
                Text("Hello, \(firstName)!")
                    .font(.title3.weight(.bold))
                    .foregroundColor(Palette.primary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                Text(periodTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Palette.primary.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Palette.mutedFill, in: Capsule())
                    .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(
                                colors: [Palette.accentAlt, Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: Palette.accent.opacity(0.35), radius: 14, x: 0, y: 10)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Add transaction")
            }
        }
    }
}

private struct AvatarCircle: View {
    var text: String

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Palette.accentAlt.opacity(0.9), Palette.accent.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 42, height: 42)
            .overlay(
                Text(initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
            )
            .shadow(color: Palette.accent.opacity(0.25), radius: 14, y: 10)
    }

    private var initials: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "U" }
        return String(trimmed.prefix(1)).uppercased()
    }
}

private struct CubertoBalanceCard: View {
    var title: String
    var amountText: String
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text(amountText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            if let action {
                Button(action: action) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.16), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Palette.accentAlt.opacity(0.95), Palette.accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Palette.accent.opacity(0.30), radius: 22, x: 0, y: 16)
    }
}

private struct SummaryCardPager: View {
    @Binding var selectedIndex: Int
    var dashboardPeriodTitle: String
    var totalBalanceText: String
    var cardsCount: Int
    var averageSpentText: String
    var savedAmount: Double
    var savedText: String
    var savingsPeriodTitle: String
    var goalAmount: Double
    var goalAmountText: String
    var goalProgress: Double?
    var showSavings: Bool
    var onOpenSavings: () -> Void
    var onAddSavings: () -> Void
    var onRemoveSavings: () -> Void
    @State private var scrollId: Int?

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let cardWidth: CGFloat = proxy.size.width - 32
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 16) {
                        TotalBalanceSummaryCard(
                            periodTitle: dashboardPeriodTitle,
                            amountText: totalBalanceText,
                            cardsCount: cardsCount,
                            averageSpentText: averageSpentText
                        )
                        .frame(width: cardWidth)
                        .id(0)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                        Group {
                            if showSavings {
                                SavingsSummaryCard(
                                    savedAmount: savedAmount,
                                    savedText: savedText,
                                    periodTitle: savingsPeriodTitle,
                                    goalAmount: goalAmount,
                                    goalAmountText: goalAmountText,
                                    goalProgress: goalProgress,
                                    onOpen: onOpenSavings,
                                    onRemove: onRemoveSavings
                                )
                            } else {
                                AddSavingsSummaryCard(onAdd: onAddSavings)
                            }
                        }
                        .frame(width: cardWidth)
                        .id(1)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $scrollId)
                .scrollClipDisabled()
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: scrollId)
                .onAppear { scrollId = selectedIndex }
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        scrollId = newValue
                    }
                }
                .onChange(of: scrollId) { _, newValue in
                    if let newValue, newValue != selectedIndex {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            selectedIndex = newValue
                        }
                    }
                }
            }
            .frame(height: 140)

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { idx in
                    Capsule()
                        .fill(idx == selectedIndex ? Palette.primary.opacity(0.45) : Palette.primary.opacity(0.16))
                        .frame(width: idx == selectedIndex ? 18 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedIndex)
                }
            }
            .padding(.top, 10)
        }
    }
}

private struct TotalBalanceSummaryCard: View {
    var periodTitle: String
    var amountText: String
    var cardsCount: Int
    var averageSpentText: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Total Balance")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))

                    Text("\(cardsCount) \(cardsCount == 1 ? "card" : "cards")")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.14), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                }

                Text(amountText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(periodTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.75))

                        AverageSpentPill(valueText: averageSpentText)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Palette.accentAlt.opacity(0.95), Palette.accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Palette.accent.opacity(0.30), radius: 22, x: 0, y: 16)
    }
}

private struct AverageSpentPill: View {
    var valueText: String

    var body: some View {
        HStack(spacing: 6) {
            Text("Avg spent")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
            Text(valueText)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

private struct SavingsSummaryCard: View {
    var savedAmount: Double
    var savedText: String
    var periodTitle: String
    var goalAmount: Double
    var goalAmountText: String
    var goalProgress: Double?
    var onOpen: () -> Void
    var onRemove: () -> Void

    var body: some View {
        let currencyCode = "EUR"
        let remaining = max(goalAmount - savedAmount, 0)

        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Savings")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))

                    Text(periodTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.14), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                }
                Text(savedText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let goalProgress {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.14))
                        
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Palette.success.opacity(0.95), Palette.accentAlt.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: nil)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(x: CGFloat(goalProgress), y: 1, anchor: .leading)
                    }
                    .frame(height: 10)

                    if goalAmount > 0 {
                        Group {
                            if savedAmount >= goalAmount {
                                Text("Goal reached • \(goalAmountText)")
                            } else {
                                Text("\(remaining.formatted(.currency(code: currencyCode))) left • Goal \(goalAmountText)")
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                } else {
                    Text("Set a goal to track progress.")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.14), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Remove savings")

                Button(action: onOpen) {
                    Image(systemName: "target")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.14), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(goalProgress == nil ? "Set goal" : "Edit goal")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Palette.success.opacity(0.65), Palette.accentAlt.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: Palette.success.opacity(0.28), radius: 22, x: 0, y: 16)
    }
}

private struct AddSavingsSummaryCard: View {
    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Savings")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text("Add savings goal")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("Swipe to come back.")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Palette.accentAlt.opacity(0.6), Palette.accent.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: Palette.accent.opacity(0.22), radius: 22, y: 14)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Add savings goal")
    }
}

private struct SavingsCard: View {
    var periodTitle: String
    var income: Double
    var expenses: Double
    var goalAmount: Double
    var onEditGoal: () -> Void
    var onRemove: () -> Void

    private let currencyCode = "EUR"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Savings")
                    .font(.headline.weight(.bold))
                    .foregroundColor(Palette.primary)

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Palette.secondary)
                        .frame(width: 32, height: 32)
                        .background(Palette.mutedFill, in: Circle())
                        .overlay(Circle().stroke(Palette.stroke, lineWidth: 1))
                        .contentShape(Circle())
                }
                .frame(width: 44, height: 44)
                .buttonStyle(PressableButtonStyle())
            }

            Text(periodTitle)
                .font(.caption.weight(.semibold))
                .foregroundColor(Palette.secondary)

            let saved = max(income - expenses, 0)
            Text(saved.formatted(.currency(code: currencyCode)))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if goalAmount > 0 {
                let progress = min(max(saved / goalAmount, 0), 1)
                ProgressBar(
                    title: "Goal \(goalAmount.formatted(.currency(code: currencyCode)))",
                    progress: progress
                )
            } else {
                Text("Set a goal to track progress.")
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Button(action: onEditGoal) {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                    Text(goalAmount > 0 ? "Edit goal" : "Set goal")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(Palette.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Palette.cardAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, tint: [Palette.success, Palette.accentAlt], shadowColor: Palette.success)
    }
}

private struct ProgressBar: View {
    var title: String
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(Palette.secondary)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.mutedFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Palette.success.opacity(0.9), Palette.accentAlt.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * CGFloat(progress))
                    }
            }
            .frame(height: 10)
        }
    }
}

private struct SavingsGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var goalAmount: Double
    @Binding var goalPeriodRaw: String
    var currentSaved: Double
    @State private var amountText: String = ""

    var body: some View {
        let currencyCode = "EUR"
        let progress = goalAmount > 0 ? min(max(currentSaved / goalAmount, 0), 1) : 0
        let remaining = max(goalAmount - currentSaved, 0)
        let period = SpendingLimitPeriod(rawValue: goalPeriodRaw) ?? .monthly

        NavigationView {
            Form {
                Section(header: Text("Progress")) {
                    HStack {
                        Text("Saved so far (\(period.title))")
                        Spacer()
                        Text(currentSaved, format: .currency(code: currencyCode))
                            .font(.subheadline.weight(.semibold))
                    }
                    if goalAmount > 0 {
                        HStack {
                            Text(currentSaved, format: .currency(code: currencyCode))
                            Spacer()
                            Text(goalAmount, format: .currency(code: currencyCode))
                        }
                        ProgressView(value: progress)
                        if currentSaved >= goalAmount {
                            Text("Goal reached!")
                                .foregroundStyle(Palette.success)
                        } else {
                            Text("\(remaining.formatted(.currency(code: currencyCode))) left to reach your goal.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Set a goal to start tracking progress.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Savings goal")) {
                    TextField("Goal amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Goal period", selection: $goalPeriodRaw) {
                        ForEach(SpendingLimitPeriod.allCases, id: \.self) { p in
                            Text(p.title).tag(p.rawValue)
                        }
                    }
                }

                Section(footer: Text("Set this to 0 to disable the goal bar.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Savings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        goalAmount = max(0, parseDecimal(amountText) ?? 0)
                        dismiss()
                    }
                }
            }
            .onAppear {
                amountText = goalAmount > 0 ? String(goalAmount) : ""
            }
        }
    }

    private func parseDecimal(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if let direct = Double(normalized) { return direct }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }
}

private struct QuickActionsCard: View {
    var onAdd: () -> Void
    var onAddCard: () -> Void
    var showAddSavings: Bool
    var onAddSavings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions")
                .font(.headline.weight(.bold))
                .foregroundColor(Palette.primary)

            VStack(spacing: 10) {
                QuickActionRow(
                    icon: "plus.circle.fill",
                    title: "Add transaction",
                    tint: Palette.accent,
                    action: onAdd
                )
                QuickActionRow(
                    icon: "creditcard.fill",
                    title: "Add card",
                    tint: Palette.accentAlt,
                    action: onAddCard
                )
                if showAddSavings {
                    QuickActionRow(
                        icon: "target",
                        title: "Add savings card",
                        tint: Palette.success,
                        action: onAddSavings
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, tint: [Palette.accentAlt, Palette.accent], shadowColor: Palette.accent)
    }
}

private struct QuickActionRow: View {
    var icon: String
    var title: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Palette.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Palette.cardAlt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct RecentTransactionsCard: View {
    var transactions: [Transaction]
    var onViewAll: () -> Void
    var onAdd: () -> Void
    private let currencyCode = "EUR"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline.weight(.bold))
                    .foregroundColor(Palette.primary)
                Spacer()
                Button(action: onViewAll) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Palette.primary.opacity(0.85))
                        .frame(width: 40, height: 40)
                        .background(Palette.mutedFill, in: Circle())
                        .overlay(Circle().stroke(Palette.stroke, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.96, pressedOpacity: 0.85))
            }

            if transactions.isEmpty {
                EmptyStateView(
                    title: "No transactions yet",
                    message: "Tap + to add your first one."
                )
            } else {
                let lastId = transactions.last?.id
                LazyVStack(spacing: 0) {
                    ForEach(transactions) { tx in
                        TransactionRow(
                            title: tx.category,
                            subtitle: Self.dateFormatter.string(from: tx.date),
                            amountText: formattedAmount(for: tx),
                            tint: tx.kind == .income ? Palette.success : Palette.danger
                        )
                        if tx.id != lastId {
                            Divider().background(Palette.stroke)
                        }
                    }
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 20, tint: [Palette.danger, Palette.accentAlt], shadowColor: Palette.danger, useMaterial: false)
    }

    private func formattedAmount(for tx: Transaction) -> String {
        let sign = tx.kind == .income ? "+" : "-"
        let absValue = abs(tx.amount)
        return "\(sign)\(absValue.formatted(.currency(code: currencyCode)))"
    }
}

private struct TransactionRow: View {
    var title: String
    var subtitle: String
    var amountText: String
    var tint: Color

    var body: some View {
        let categoryColor = CategoryColors.color(for: title)
        let icon = iconName(for: title)

        HStack(spacing: 12) {
            Circle()
                .fill(categoryColor.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(categoryColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(categoryColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
            }

            Spacer()
            Text(amountText)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
        }
        .padding(.vertical, 12)
    }

    private func iconName(for category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("food") || lower.contains("restaurant") || lower.contains("cafe") { return "fork.knife" }
        if lower.contains("rent") || lower.contains("home") { return "house.fill" }
        if lower.contains("uber") || lower.contains("taxi") || lower.contains("transport") { return "car.fill" }
        if lower.contains("shopping") || lower.contains("amazon") { return "bag.fill" }
        if lower.contains("salary") || lower.contains("pay") { return "creditcard.fill" }
        return "circle.fill"
    }
}

private struct WalletCardPager: View {
    var cards: [CardInfo]
    @Binding var selectedCardIndex: Int
    var transactions: [Transaction]
    var overLimitCardIds: Set<UUID> = []
    var onAddCard: () -> Void
    var onOpenCards: () -> Void
    private let currencyCode = "EUR"
    @State private var scrollId: Int?
    @State private var cachedSeries: [UUID: [Double]] = [:]

    var body: some View {
        if cards.isEmpty {
            EmptyWalletCard(onAdd: onAddCard)
        } else {
            VStack(spacing: 10) {
                GeometryReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 16) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                                let theme = CardTheme.theme(for: card, index: idx)
                                let limitText: String? = card.primaryLimitForDisplay().map { entry in
                                    "\(entry.period.title) \(entry.limit.formatted(.currency(code: currencyCode)))"
                                }
                                WalletCard(
                                    title: card.nickname.isEmpty ? "Wallet" : card.nickname,
                                    limitText: limitText,
                                    amountText: (card.balance ?? 0).formatted(.currency(code: currencyCode)),
                                    values: getCachedSeries(cardId: card.id),
                                    theme: theme,
                                    isOverLimit: overLimitCardIds.contains(card.id)
                                )
                                .frame(width: proxy.size.width)
                                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                .onTapGesture { onOpenCards() }
                                .id(idx)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 2)
                        .padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $scrollId)
                    .scrollClipDisabled()
                    .onAppear {
                        scrollId = selectedCardIndex
                        updateCachedSeries()
                    }
                    .onChange(of: transactions.count) { _, _ in
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            updateCachedSeries()
                        }
                    }
                    .onChange(of: selectedCardIndex) { _, newValue in
                        scrollId = newValue
                    }
                    .onChange(of: scrollId) { _, newValue in
                        if let newValue, newValue != selectedCardIndex {
                            selectedCardIndex = newValue
                        }
                    }
                    .onDisappear {
                        cachedSeries.removeAll()
                    }
                }
                .frame(height: 232)

                HStack(spacing: 6) {
                    ForEach(0..<cards.count, id: \.self) { idx in
                        Capsule()
                            .fill(idx == selectedCardIndex ? Color.white.opacity(0.65) : Color.white.opacity(0.18))
                            .frame(width: idx == selectedCardIndex ? 18 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedCardIndex)
                    }
                }
            }
        }
    }

    private func getCachedSeries(cardId: UUID) -> [Double] {
        if let cached = cachedSeries[cardId] {
            return cached
        }
        let series = dailyNetSeries(cardId: cardId, days: 12)
        DispatchQueue.main.async { [self] in
            cachedSeries[cardId] = series
        }
        return series
    }

    private func updateCachedSeries() {
        let cardIds = Set(cards.map { $0.id })
        cachedSeries = cachedSeries.filter { cardIds.contains($0.key) }
        
        for card in cards where cachedSeries[card.id] == nil {
            cachedSeries[card.id] = dailyNetSeries(cardId: card.id, days: 12)
        }
    }

    private func dailyNetSeries(cardId: UUID, days: Int) -> [Double] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return [] }

        var dailyAmounts = Array(repeating: 0.0, count: days)
        
        for tx in transactions where (tx.cardId == nil || tx.cardId == cardId) && tx.date >= start {
            let txDay = calendar.startOfDay(for: tx.date)
            if let dayIndex = calendar.dateComponents([.day], from: start, to: txDay).day, dayIndex >= 0 && dayIndex < days {
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

private struct EmptyWalletCard: View {
    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wallet")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                        Text("Add a card to track balances.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.78))
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
                        .accessibilityHidden(true)
                }

                HStack(spacing: 10) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Add card")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .opacity(0.9)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Palette.accentAlt.opacity(0.6), Palette.accent.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: Palette.accent.opacity(0.22), radius: 22, y: 14)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Add card")
    }
}

private struct WalletCard: View {
    var title: String
    var limitText: String?
    var amountText: String
    var values: [Double]
    var theme: CardTheme.Theme
    var isOverLimit: Bool

	    var body: some View {
	        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
	        let strokeColors = isOverLimit ? [Color.red.opacity(0.95), Color.orange.opacity(0.7)] : theme.stroke
	        let glowColor = isOverLimit ? Color.red : theme.glow

	        ZStack {
            shape
                .fill(
                    LinearGradient(
                        colors: theme.background.map { $0.opacity(0.94) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.22), .clear]),
                        center: .topTrailing,
                        startRadius: 30,
                        endRadius: 240
                    )
                    .blendMode(.screen)
                    .clipShape(shape)
                    .allowsHitTesting(false)
                )
                .overlay(
                    Group {
                        if isOverLimit {
                            RadialGradient(
                                colors: [Color.red.opacity(0.40), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                            .blendMode(.screen)
                            .blur(radius: 4)
                            .clipShape(shape)
                            .allowsHitTesting(false)
                        }
                    }
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(colors: strokeColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.1
                    )
                )
                .shadow(color: glowColor.opacity(isOverLimit ? 0.35 : 0.18), radius: isOverLimit ? 20 : 16, y: 12)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                    if let limitText {
                        Text(limitText)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(isOverLimit ? Color.red.opacity(0.95) : Color.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.white.opacity(isOverLimit ? 0.10 : 0.14), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
                }

                Text(amountText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                LineSpark(values: values)
                    .frame(height: 54)

                Text("Total receive")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
        }
    }
}

private struct LineSpark: View {
    var values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let points = normalize(values: values, size: proxy.size)
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

            ZStack(alignment: .leading) {
                shape
                    .fill(Color.white.opacity(0.10))
                    .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))

                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        addSmoothLine(into: &path, points: points)
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                    Path { path in
                        guard let first = points.first, let last = points.last else { return }
                        path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                        path.addLine(to: first)
                        addSmoothLine(into: &path, points: points)
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.15))
                }
            }
        }
    }

    private func addSmoothLine(into path: inout Path, points: [CGPoint], tension: CGFloat = 1) {
        guard points.count >= 2 else { return }
        if points.count == 2 {
            path.addLine(to: points[1])
            return
        }

        for idx in 0..<(points.count - 1) {
            let p0 = points[max(idx - 1, 0)]
            let p1 = points[idx]
            let p2 = points[idx + 1]
            let p3 = points[min(idx + 2, points.count - 1)]

            let d1 = CGPoint(x: (p2.x - p0.x) / 6 * tension, y: (p2.y - p0.y) / 6 * tension)
            let d2 = CGPoint(x: (p3.x - p1.x) / 6 * tension, y: (p3.y - p1.y) / 6 * tension)

            let control1 = CGPoint(x: p1.x + d1.x, y: p1.y + d1.y)
            let control2 = CGPoint(x: p2.x - d2.x, y: p2.y - d2.y)

            path.addCurve(to: p2, control1: control1, control2: control2)
        }
    }

    private func normalize(values: [Double], size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let range = max(maxValue - minValue, 0.0001)
        let insetX: CGFloat = 14
        let insetY: CGFloat = 10
        let w = max(1, size.width - insetX * 2)
        let h = max(1, size.height - insetY * 2)

        return values.enumerated().map { idx, v in
            let t = CGFloat(idx) / CGFloat(values.count - 1)
            let x = insetX + w * t
            let normalized = (v - minValue) / range
            let y = insetY + (1 - CGFloat(normalized)) * h
            return CGPoint(x: x, y: y)
        }
    }
}
