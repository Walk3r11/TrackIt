import SwiftUI

struct CubertoDashboardLayout: View {

    // MARK: - Properties

    var userId: String?
    var firstName: String
    @Binding var selectedPeriod: Period
    var totalBalance: Double
    var income: Double
    var expenses: Double
    var cards: [CardInfo]
    @Binding var selectedCardIndex: Int
    var transactions: [Transaction]
    var transactionsForList: [Transaction]
    var incomeCategoryBreakdown: [String: Double]
    var expenseCategoryBreakdown: [String: Double]
    var overLimitCardIds: Set<UUID> = []

    // MARK: - Callbacks

    var onAddTransaction: () -> Void
    var onViewAllTransactions: () -> Void
    var onAddCard: () -> Void
    var onOpenCards: () -> Void

    // MARK: - State

    @StateObject private var viewModel = DashboardViewModel()
    @AppStorage("showSavingsCard") private var showSavingsCard = false
    @AppStorage("savingsGoalAmount") private var savingsGoalAmount: Double = 0
    @AppStorage("savingsSavedAmount") private var savingsSavedAmount: Double = 0
    @AppStorage("savingsGoalPeriod") private var savingsGoalPeriodRaw: String = SpendingLimitPeriod.monthly.rawValue
    @State private var showSavingsGoalSheet = false
    @State private var summaryIndex = 0
    @State private var suppressSavingsSync = false
    @State private var loadDataTask: Task<Void, Never>?

    private var goalPeriod: SpendingLimitPeriod {
        SpendingLimitPeriod(rawValue: savingsGoalPeriodRaw) ?? .monthly
    }

    private var goalProgress: Double? {
        guard savingsGoalAmount > 0 else { return nil }
        return min(max(viewModel.savedAmount / savingsGoalAmount, 0), 1)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 22) {
                heroSection
                walletSection
                summarySection
                insightsSection
                recentTransactionsSection
            }
            .frame(maxWidth: LayoutMetrics.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .task {
            await loadData()
        }
        .task(id: selectedPeriod) {

            try? await Task.sleep(nanoseconds: 100_000_000)
            await loadData()
        }
        .task(id: transactions.count) {

            try? await Task.sleep(nanoseconds: 150_000_000)
            await loadData()
        }
        .task(id: userId ?? "") {
            await loadRemoteGoal()
        }
        .task(id: savingsGoalPeriodRaw) {
            handleGoalPeriodChange()
        }
        .task(id: savingsGoalAmount) {
            syncGoalIfNeeded()
        }
        .onChange(of: showSavingsCard) { _, enabled in
            handleShowSavingsChange(enabled)
        }
        .onReceive(savingsGoalNotification) { handleNotification($0) }
        .sheet(isPresented: $showSavingsGoalSheet) {
            SavingsGoalSheet(
                goalAmount: $savingsGoalAmount,
                goalPeriodRaw: $savingsGoalPeriodRaw,
                currentSaved: viewModel.savedAmount
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - View Sections

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CubertoHeader(
                firstName: firstName,
                onAdd: onAddTransaction
            )

            quickActionStrip
        }
        .padding(20)
        .glassCard(
            cornerRadius: 26,
            tint: [Palette.cardAlt, Palette.card],
            shadowColor: Palette.shadowStrong
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Palette.accent)
                .frame(width: 54, height: 4)
                .padding(.top, 12)
                .padding(.leading, 18)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(
                title: "Highlights",
                subtitle: selectedPeriod.title
            )

            SummaryCardPager(
                selectedIndex: $summaryIndex,
                dashboardPeriodTitle: selectedPeriod.title,
                totalBalanceText: totalBalance.formattedAsCurrency(),
                cardsCount: cards.count,
                averageSpentText: viewModel.averageSpent,
                savedAmount: viewModel.savedAmount,
                savedText: viewModel.savedAmount.formattedAsCurrency(),
                savingsPeriodTitle: goalPeriod.title,
                goalAmount: savingsGoalAmount,
                goalAmountText: savingsGoalAmount.formattedAsCurrency(),
                goalProgress: goalProgress,
                showSavings: showSavingsCard,
                onOpenSavings: { showSavingsGoalSheet = true },
                onAddSavings: addSavingsGoal,
                onRemoveSavings: removeSavingsCard
            )
            .padding(.horizontal, -LayoutMetrics.horizontalPadding)
        }
        .padding(.top, 4)
    }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(
                title: "Wallets",
                subtitle: "\(cards.count) \(cards.count == 1 ? "card" : "cards")"
            )

            WalletCardPager(
                cards: cards,
                selectedCardIndex: $selectedCardIndex,
                transactions: transactions,
                overLimitCardIds: viewModel.overLimitCardIds,
                onAddCard: onAddCard,
                onOpenCards: onOpenCards
            )
            .padding(.horizontal, -LayoutMetrics.horizontalPadding)
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(
                title: "Spending Pulse",
                subtitle: selectedPeriod.title
            )

            HorizontalFadeScrollView(showsIndicators: false, fadeWidth: 40) {
                PeriodPicker(selectedPeriod: $selectedPeriod)
            }
            .padding(12)
            .glassCard(
                cornerRadius: 16,
                tint: [Palette.cardAlt, Palette.card],
                shadowColor: Palette.shadow
            )

            SnapshotCard(
                title: "Spending Overview",
                subtitle: selectedPeriod.title,
                income: income,
                expenses: expenses,
                incomeCategoryBreakdown: incomeCategoryBreakdown,
                expenseCategoryBreakdown: expenseCategoryBreakdown
            )
            .id("snapshot-\(selectedPeriod.rawValue)-\(income)-\(expenses)")
        }
    }

    private var recentTransactionsSection: some View {
        RecentTransactionsCard(
            transactions: Array(transactionsForList.prefix(5)),
            onViewAll: onViewAllTransactions,
            onAdd: onAddTransaction
        )
        .padding(.top, 6)
        .id("recent-transactions-\(transactionsForList.prefix(5).map { $0.id.uuidString }.joined())")
    }

    private var quickActionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                QuickActionChip(
                    icon: "plus",
                    title: "Add",
                    tint: Palette.accent,
                    action: onAddTransaction
                )

                QuickActionChip(
                    icon: "creditcard",
                    title: "New card",
                    tint: Palette.accentAlt,
                    action: onAddCard
                )

                QuickActionChip(
                    icon: "target",
                    title: showSavingsCard ? "Goal" : "Set goal",
                    tint: Palette.success,
                    action: {
                        if showSavingsCard {
                            showSavingsGoalSheet = true
                        } else {
                            addSavingsGoal()
                        }
                    }
                )
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {

        loadDataTask?.cancel()
        loadDataTask = Task {
            await viewModel.updateMetrics(
                cards: cards,
                transactions: transactions,
                period: selectedPeriod,
                savingsGoal: savingsGoalAmount,
                savingsPeriod: goalPeriod
            )
            guard !Task.isCancelled else { return }
            savingsSavedAmount = viewModel.savedAmount
        }
        await loadDataTask?.value
    }

    private func loadRemoteGoal() async {
        guard let userId else { return }
        do {
            let remote = try await APIClient.shared.fetchSavingsGoal(userId: userId)
            suppressSavingsSync = true
            savingsGoalAmount = remote.goalAmount
            savingsGoalPeriodRaw = remote.goalPeriod.rawValue
            suppressSavingsSync = false
        } catch {
            suppressSavingsSync = false
        }
    }

    // MARK: - Actions

    private func addSavingsGoal() {

        showSavingsCard = true
        showSavingsGoalSheet = true
    }

    private func removeSavingsCard() {

        showSavingsCard = false
    }

    // MARK: - State Sync

    private func handleGoalPeriodChange() {
        Task { await loadData() }
        guard !suppressSavingsSync, let userId else { return }
        Task {
            try? await APIClient.shared.updateSavingsGoal(
                userId: userId,
                goalAmount: savingsGoalAmount,
                goalPeriod: goalPeriod
            )
        }
    }

    private func syncGoalIfNeeded() {
        guard !suppressSavingsSync, let userId else { return }
        Task {
            try? await APIClient.shared.updateSavingsGoal(
                userId: userId,
                goalAmount: savingsGoalAmount,
                goalPeriod: goalPeriod
            )
        }
    }

    private func handleShowSavingsChange(_ enabled: Bool) {
        if !enabled && summaryIndex == 1 {
            summaryIndex = 0
        }
    }

    // MARK: - Notifications

    private var savingsGoalNotification: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: NSNotification.Name("SavingsGoalUpdated"))
    }

    private func handleNotification(_ notification: NotificationCenter.Publisher.Output) {
        guard let userInfo = notification.userInfo,
              let goalAmount = userInfo["goalAmount"] as? Double,
              let goalPeriodRaw = userInfo["goalPeriod"] as? String else { return }

        Task { @MainActor in
            suppressSavingsSync = true
            savingsGoalAmount = goalAmount
            savingsGoalPeriodRaw = goalPeriodRaw
            if goalAmount > 0 {
                showSavingsCard = true
            }
            suppressSavingsSync = false
            await loadData()
        }
    }
}

private struct DashboardSectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appFont(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(Palette.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.appFont(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.tertiary)
                        .textCase(.uppercase)
                        .kerning(0.6)
                }
            }

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.appFont(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Palette.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Palette.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(PressableButtonStyle(scale: 0.98, pressedOpacity: 0.9))
            }
        }
    }
}

private struct QuickActionChip: View {
    var icon: String
    var title: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: icon)
                            .font(.appFont(size: 11, weight: .semibold))
                            .foregroundColor(tint)
                    )
                Text(title)
                    .font(.appFont(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Palette.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98, pressedOpacity: 0.9))
    }
}
