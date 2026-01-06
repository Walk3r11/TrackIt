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

            CubertoDashboardLayout(
                userId: userId,
                firstName: firstName,
                selectedPeriod: $selectedPeriod,
                totalBalance: totalBalance,
                income: totalIncome,
                expenses: totalExpenses,
                cards: cards,
                selectedCardIndex: $selectedCardIndex,
                transactions: transactions,
                incomeCategoryBreakdown: incomeCategoryBreakdown,
                expenseCategoryBreakdown: expenseCategoryBreakdown,
                overLimitCardIds: overLimitCardIds,
                onAddTransaction: onAddTransaction,
                onViewAllTransactions: { showTransactionsSheet = true },
                onAddCard: onAddCard,
                onOpenCards: onOpenCards
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 12)
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

    private var totalBalance: Double {
        cards.reduce(0) { $0 + ($1.balance ?? 0) }
    }
}
