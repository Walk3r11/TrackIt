import SwiftUI

struct HomeDashboard: View {
    var userId: String?
    var firstName: String
    @Binding var selectedPeriod: Period
    @Binding var shimmerOffset: CGFloat
    @Binding var transactions: [Transaction]
    @Binding var showAddSheet: Bool
    @Binding var cardsLocked: Bool
    @Binding var showAddCardSheet: Bool
    @Binding var cards: [CardInfo]
    var overLimitCardIds: Set<UUID>
    @Binding var selectedCardIndex: Int
    @Binding var showTransactionsSheet: Bool
    @State private var pendingAddFromTransactionsSheet = false
    @State private var cardsScrollId: Int?
    var categories: [String]
    var netBalance: Double
    var totalIncome: Double
    var totalExpenses: Double
    var lifetimeIncome: Double
    var lifetimeExpenses: Double
    var incomeCategoryBreakdown: [String: Double]
    var expenseCategoryBreakdown: [String: Double]
    var filteredTransactions: [Transaction]
    var onAddCard: () -> Void
    var onAddTransaction: () -> Void
    var onNewCategory: (String) -> Void
    var onSyncTransaction: (Transaction) -> Void
    var onSyncCard: (CardInfo) -> Void
    var onAdjustBalance: (Transaction) -> Void
    var onOpenCards: () -> Void

    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    balanceHero
                    quickActions
                    cardsStrip
                    recentActivity
                    spendingBreakdown
                    Spacer(minLength: 20)
                }
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showAddCardSheet) {
            AddCardSheet { card in
                cards.append(card)
                onSyncCard(card)
                cardsLocked = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTransactionsSheet) {
            AllTransactionsSheet(transactions: transactions) {
                pendingAddFromTransactionsSheet = true
                showTransactionsSheet = false
            }
        }
        .onChange(of: showTransactionsSheet) { _, isPresented in
            guard !isPresented, pendingAddFromTransactionsSheet else { return }
            pendingAddFromTransactionsSheet = false
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    showAddSheet = true
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionSheet(
                categories: categories,
                onSave: { newTransaction in
                    var tx = newTransaction
                    if tx.cardId == nil, cards.indices.contains(selectedCardIndex) {
                        tx.cardId = cards[selectedCardIndex].id
                    }
                    guard tx.cardId != nil else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            showAddSheet = false
                            showAddCardSheet = true
                        }
                        return
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        transactions.insert(tx, at: 0)
                    }
                    onNewCategory(tx.category)
                    onSyncTransaction(tx)
                    onAdjustBalance(tx)
                },
                onNewCategory: { onNewCategory($0) },
                selectedCardId: cards.indices.contains(selectedCardIndex) ? cards[selectedCardIndex].id : nil
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hello, \(firstName)")
                        .font(.appFont(size: 28, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.appFont(size: 14, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                }

                Spacer()

                Button {
                    onOpenCards()
                } label: {
                    Image(systemName: "creditcard")
                        .font(.appFont(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                        .frame(width: 40, height: 40)
                        .minimalSurface(cornerRadius: 14)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Net Balance")
                    .font(.appFont(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                Text(selectedPeriod.title)
                    .font(.appFont(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
            }

            Text(netBalance.formatted(.currency(code: AppConstants.Currency.code)))
                .font(.appFont(size: 34, weight: .bold))
                .foregroundStyle(Palette.primary)

            HStack(spacing: 16) {
                MetricChip(title: "Income", value: totalIncome, color: Palette.success)
                MetricChip(title: "Expenses", value: totalExpenses, color: Palette.danger)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPeriod = period
                            }
                        } label: {
                            Text(period.title)
                                .font(.appFont(size: 12, weight: .semibold))
                                .foregroundStyle(selectedPeriod == period ? Color.white : Palette.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedPeriod == period ? Palette.primary : Palette.card)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Palette.stroke, lineWidth: 1)
                                )
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 2)
                .padding(.trailing, 24)
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .minimalSurface(cornerRadius: 20)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            ActionTile(title: "Add", subtitle: "Transaction", systemImage: "plus") {
                onAddTransaction()
            }

            ActionTile(title: "New", subtitle: "Card", systemImage: "creditcard") {
                onAddCard()
            }

            ActionTile(title: "All", subtitle: "Activity", systemImage: "list.bullet") {
                showTransactionsSheet = true
            }
        }
    }

    private var cardsStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cards")
                    .font(.appFont(size: 18, weight: .semibold))
                Spacer()
                Button("Manage") {
                    onOpenCards()
                }
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            }

            if cards.isEmpty {
                Button {
                    onAddCard()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.appFont(size: 22, weight: .semibold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add your first card")
                                .font(.appFont(size: 15, weight: .semibold))
                            Text("Track balances and limits.")
                                .font(.appFont(size: 12))
                                .foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                GeometryReader { geo in
                    let cardWidth = geo.size.width
                    VStack(spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 0) {
                                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                    CardTile(card: card, isOverLimit: overLimitCardIds.contains(card.id))
                                        .frame(width: cardWidth)
                                        .id(index)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $cardsScrollId)
                        .onAppear {
                            cardsScrollId = selectedCardIndex
                        }
                        .onChange(of: selectedCardIndex) { _, newValue in
                            cardsScrollId = newValue
                        }
                        .onChange(of: cardsScrollId) { _, newValue in
                            if let newValue, newValue != selectedCardIndex {
                                selectedCardIndex = newValue
                            }
                        }

                        if cards.count > 1 {
                            HStack(spacing: 6) {
                                ForEach(0..<cards.count, id: \.self) { index in
                                    Capsule()
                                        .fill(index == selectedCardIndex ? Palette.primary : Palette.stroke)
                                        .frame(width: index == selectedCardIndex ? 18 : 6, height: 6)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: selectedCardIndex)
                        }
                    }
                }
                .frame(height: 140)
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.appFont(size: 18, weight: .semibold))
                Spacer()
                Button("See all") {
                    showTransactionsSheet = true
                }
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            }

            if filteredTransactions.isEmpty {
                Text("No transactions yet.")
                    .font(.appFont(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimalSurface(cornerRadius: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredTransactions.prefix(5)) { tx in
                        HomeTransactionRow(tx: tx)
                    }
                }
            }
        }
    }

    private var spendingBreakdown: some View {
        let topItems = expenseCategoryBreakdown.sorted { $0.value > $1.value }.prefix(4)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Spending Breakdown")
                .font(.appFont(size: 18, weight: .semibold))

            if topItems.isEmpty {
                Text("No category data yet.")
                    .font(.appFont(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimalSurface(cornerRadius: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topItems), id: \.key) { category, amount in
                        CategoryBar(title: category, value: amount, total: totalExpenses)
                    }
                }
                .padding(14)
                .minimalSurface(cornerRadius: 18)
            }
        }
    }

    private var totalBalance: Double {
        cards.reduce(0) { $0 + ($1.balance ?? 0) }
    }
}

private struct MetricChip: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            Spacer()
            Text(value.formatted(.currency(code: AppConstants.Currency.code)))
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt)
    }
}

private struct ActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Circle()
                    .fill(Palette.cardAlt)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.appFont(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                    )

                Text(title)
                    .font(.appFont(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text(subtitle)
                    .font(.appFont(size: 9))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 68, alignment: .topLeading)
            .padding(8)
            .minimalSurface(cornerRadius: 16, fill: Palette.card)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct CardTile: View {
    let card: CardInfo
    let isOverLimit: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.nickname.isEmpty ? "Card" : card.nickname)
                .font(.appFont(size: 16, weight: .semibold))
                .foregroundStyle(Palette.primary)

            Text(card.balance ?? 0, format: .currency(code: AppConstants.Currency.code))
                .font(.appFont(size: 22, weight: .bold))
                .foregroundStyle(Palette.primary)

            if let primaryLimit = card.primaryLimitForDisplay() {
                HStack(spacing: 6) {
                    Text("\(primaryLimit.period.title) limit")
                        .font(.appFont(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.secondary)
                    Spacer()
                    Text(primaryLimit.limit, format: .currency(code: AppConstants.Currency.code))
                        .font(.appFont(size: 11, weight: .semibold))
                        .foregroundStyle(isOverLimit ? Palette.danger : Palette.primary)
                }
            }

            if isOverLimit {
                Text("Over limit")
                    .font(.appFont(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.danger)
            }
        }
        .padding(16)
        .minimalSurface(cornerRadius: 18)
    }
}

private struct HomeTransactionRow: View {
    let tx: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tx.kind == .income ? Palette.success.opacity(0.2) : Palette.danger.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: tx.kind == .income ? "arrow.down" : "arrow.up")
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundStyle(tx.kind == .income ? Palette.success : Palette.danger)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(tx.category)
                    .font(.appFont(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.appFont(size: 11))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer()

            Text(tx.amount.formatted(.currency(code: AppConstants.Currency.code)))
                .font(.appFont(size: 13, weight: .semibold))
                .foregroundStyle(tx.kind == .income ? Palette.success : Palette.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .minimalSurface(cornerRadius: 16, fill: Palette.cardAlt)
    }
}

private struct CategoryBar: View {
    let title: String
    let value: Double
    let total: Double

    var body: some View {
        let ratio = total > 0 ? min(1, value / total) : 0
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.appFont(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                Spacer()
                Text(value.formatted(.currency(code: AppConstants.Currency.code)))
                    .font(.appFont(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.mutedFillStrong)
                    Capsule()
                        .fill(Palette.primary)
                        .frame(width: max(8, proxy.size.width * ratio))
                }
            }
            .frame(height: 6)
        }
    }
}
