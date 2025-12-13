import SwiftUI
import LocalAuthentication

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var selectedPeriod: Period = .daily
    @State private var shimmerOffset: CGFloat = -300
    @State private var showAddSheet = false
    @State private var showAddCardSheet = false
    @State private var selectedCardDetail: CardInfo?
    @State private var requireCardUnlock = true
    @State private var cardsLocked = true
    @State private var selectedCardIndex = 0
    @State private var transactions: [Transaction] = []
    @State private var categories: [String] = []
    @State private var cards: [CardInfo] = []
    @State private var supportTickets: [SupportTicket] = [
        SupportTicket(subject: "Card not showing", detail: "Card carousel empty after refresh."),
        SupportTicket(subject: "Balance mismatch", detail: "Net balance seems off vs bank.")
    ]
    @State private var showSupportSheet = false
    @State private var showTransactionsSheet = false

var body: some View {
    TabView(selection: $selectedTab) {
        dashboard
            .tag(0)
            .tabItem { Label("Home", systemImage: "house.fill") }

            CardsTab(
                cards: $cards,
                requireCardUnlock: requireCardUnlock,
                locked: $cardsLocked,
                showAddCardSheet: $showAddCardSheet,
                unlock: authenticateCards,
                onSelect: { card in selectedCardDetail = card },
                onSyncCard: { card in syncCard(card) },
                onDeleteCard: { card in deleteCard(card) }
            )
            .tag(1)
            .tabItem { Label("Cards", systemImage: "creditcard.fill") }

            PlaceholderTab(title: "AI")
                .tag(2)
                .tabItem { Label("AI", systemImage: "brain.head.profile") }

            SettingsTab(
                categories: $categories,
                requireCardUnlock: $requireCardUnlock,
                supportTickets: $supportTickets,
                showSupportSheet: $showSupportSheet,
                onToggleCardLock: { enabled in
                    requireCardUnlock = enabled
                    cardsLocked = enabled
                }
            )
            .environmentObject(session)
            .onAppear {
                refreshFromServer()
            }
            .tag(3)
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .preferredColorScheme(.dark)
        .appBackground()
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
            .onAppear {
                loadPersistedData()
                refreshFromServer()
            }
        .task(id: session.user?.id) {
            refreshFromServer()
        }
        .task(id: session.token) {
            refreshFromServer()
        }
        .onChange(of: session.user?.id ?? "") { _, _ in
            refreshFromServer()
        }
        .onChange(of: session.token ?? "") { _, _ in
            refreshFromServer()
        }
        .onChange(of: cards) { _, _ in
            saveCards()
        }
        .onChange(of: transactions) { _, _ in
            saveTransactions()
        }
        .onChange(of: categories) { _, _ in
            saveCategories()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if (newPhase == .background || newPhase == .inactive) && requireCardUnlock {
                cardsLocked = true
            } else if newPhase == .active {
                refreshFromServer()
            }
        }
        .sheet(item: $selectedCardDetail) { card in
            CardDetailSheet(
                card: card,
                onUpdate: { updated in
                    if let idx = cards.firstIndex(where: { $0.id == updated.id }) {
                        cards[idx] = updated
                        updateCardRemote(updated)
                    }
                    selectedCardDetail = nil
                },
                onDelete: {
                    deleteCard(card)
                    selectedCardDetail = nil
                }
            )
        }
        .sheet(isPresented: $showSupportSheet) {
            SupportTicketSheet { subject, detail in
                let ticket = SupportTicket(subject: subject, detail: detail)
                supportTickets.insert(ticket, at: 0)
            }
        }
    }

    private func refreshFromServer() {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                let remoteCards = try await APIClient.shared.fetchCards(userId: userId)
                await MainActor.run {
                    cards = remoteCards
                    saveCards()
                }
            } catch {
                print("Fetch cards failed:", error)
            }
            do {
                let remoteTx = try await APIClient.shared.fetchTransactions(userId: userId)
                await MainActor.run {
                    transactions = remoteTx
                    saveTransactions()
                }
            } catch {
                print("Fetch transactions failed:", error)
            }
        }
    }

    private var dashboard: some View {
        let income = totalIncome
        let net = netBalance
        let breakdown = categoryBreakdown
        let filtered = filteredTransactions

        return HomeDashboard(
            selectedPeriod: $selectedPeriod,
            shimmerOffset: $shimmerOffset,
            transactions: $transactions,
            showAddSheet: $showAddSheet,
            cardsLocked: $cardsLocked,
            showAddCardSheet: $showAddCardSheet,
            cards: $cards,
            selectedCardIndex: $selectedCardIndex,
            showTransactionsSheet: $showTransactionsSheet,
            categories: categories,
            netBalance: net,
            totalIncome: income,
            totalExpenses: totalExpensesMagnitude,
            lifetimeIncome: lifetimeIncome,
            lifetimeExpenses: lifetimeExpensesMagnitude,
            categoryBreakdown: breakdown, filteredTransactions: filtered,
            onAddCard: { showAddCardSheet = true },
            onAddTransaction: {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    showAddSheet = true
                }
            },
            onNewCategory: { addCategoryIfNeeded($0) },
            onSyncTransaction: { tx in
                syncTransaction(tx)
            },
            onSyncCard: { card in syncCard(card) },
            onAdjustBalance: { tx in adjustBalance(for: tx) }
        )
    }

    private func authenticateCards() {
        if !requireCardUnlock {
            cardsLocked = false
            return
        }
        guard !cards.isEmpty else {
            cardsLocked = false
            return
        }

        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your cards") { success, _ in
                DispatchQueue.main.async {
                    cardsLocked = !success
                }
            }
        } else {
            cardsLocked = false
        }
    }

    private var periodStart: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .daily:
            return calendar.startOfDay(for: .now)
        case .weekly:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        case .biweekly:
            return calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: .now)) ?? .now
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
        case .quarterly:
            return calendar.date(byAdding: .month, value: -3, to: .now) ?? .now
        case .semiannual:
            return calendar.date(byAdding: .month, value: -6, to: .now) ?? .now
        case .nineMonth:
            return calendar.date(byAdding: .month, value: -9, to: .now) ?? .now
        case .yearly:
            return calendar.date(byAdding: .year, value: -1, to: .now) ?? .now
        }
    }

    private var selectedCardId: UUID? {
        cards.indices.contains(selectedCardIndex) ? cards[selectedCardIndex].id : nil
    }

    private var filteredTransactions: [Transaction] {
        transactions.filter { tx in
            guard tx.date >= periodStart else { return false }
            if let cardId = selectedCardId {
                return tx.cardId == cardId
            }
            return true
        }
    }

    private var lifetimeIncome: Double {
        transactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var lifetimeExpensesMagnitude: Double {
        transactions
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + abs($1.amount) }
    }

    private var totalIncome: Double {
        filteredTransactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalExpensesMagnitude: Double {
        filteredTransactions
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + abs($1.amount) }
    }

    private var netBalance: Double {
        totalIncome - totalExpensesMagnitude
    }

    private var categoryBreakdown: [String: Double] {
        filteredTransactions
            .filter { $0.kind == .expense }
            .reduce(into: [:]) { partialResult, transaction in
                partialResult[transaction.category, default: 0] += abs(transaction.amount)
            }
    }

    private func loadPersistedData() {
        if let storedCards: [CardInfo] = SecureStore.load([CardInfo].self, key: "cards") {
            cards = storedCards
            if !storedCards.isEmpty { cardsLocked = true }
        }
        if let storedTransactions: [Transaction] = SecureStore.load([Transaction].self, key: "transactions") {
            transactions = storedTransactions
        }
        if let storedCategories: [String] = SecureStore.load([String].self, key: "categories") {
            categories = storedCategories
        } else {
            categories = ["Dining", "Groceries", "Travel", "Bills", "Shopping", "Transfers"]
        }

        Task {
            guard let userId = session.user?.id else { return }
            if cards.isEmpty {
                if let remoteCards = try? await APIClient.shared.fetchCards(userId: userId) {
                    await MainActor.run {
                        cards = remoteCards
                        if !remoteCards.isEmpty { cardsLocked = true }
                        saveCards()
                    }
                }
            }
            if transactions.isEmpty {
                if let remoteTx = try? await APIClient.shared.fetchTransactions(userId: userId) {
                    await MainActor.run {
                        transactions = remoteTx
                        saveTransactions()
                    }
                }
            }
        }
    }

    private func saveCards() {
        SecureStore.save(cards, key: "cards")
    }

    private func saveTransactions() {
        SecureStore.save(transactions, key: "transactions")
    }

    private func saveCategories() {
        SecureStore.save(categories, key: "categories")
    }

    private func addCategoryIfNeeded(_ category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !categories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            categories.append(trimmed)
        }
    }

    private func syncCard(_ card: CardInfo) {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                try await APIClient.shared.saveCard(userId: userId, card: card)
            } catch {
                print("Save card failed:", error)
            }
        }
    }

    private func syncTransaction(_ tx: Transaction) {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                try await APIClient.shared.saveTransaction(userId: userId, transaction: tx)
            } catch {
                print("Save transaction failed:", error)
            }
        }
    }

    private func updateCardRemote(_ card: CardInfo) {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                try await APIClient.shared.updateCard(userId: userId, card: card)
            } catch {
                print("Update card failed:", error)
            }
        }
    }

    private func deleteCardRemote(_ card: CardInfo) {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                try await APIClient.shared.deleteCard(userId: userId, cardId: card.id)
            } catch {
                print("Delete card failed:", error)
            }
        }
    }

    private func deleteCard(_ card: CardInfo) {
        cards.removeAll { $0.id == card.id }
        deleteCardRemote(card)
    }

    private func adjustBalance(for transaction: Transaction) {
        guard !cards.isEmpty else { return }
        let targetId = transaction.cardId ?? (cards.indices.contains(selectedCardIndex) ? cards[selectedCardIndex].id : nil)
        guard let cardId = targetId, let idx = cards.firstIndex(where: { $0.id == cardId }) else { return }
        var card = cards[idx]
        card.balance = (card.balance ?? 0) + transaction.amount
        cards[idx] = card
        updateCardRemote(card)
    }
}

// MARK: - Tabs
struct HomeDashboard: View {
    @Binding var selectedPeriod: Period
    @Binding var shimmerOffset: CGFloat
    @Binding var transactions: [Transaction]
    @Binding var showAddSheet: Bool
    @Binding var cardsLocked: Bool
    @Binding var showAddCardSheet: Bool
    @Binding var cards: [CardInfo]
    @Binding var selectedCardIndex: Int
    @Binding var showTransactionsSheet: Bool
    var categories: [String]
    var netBalance: Double
    var totalIncome: Double
    var totalExpenses: Double
    var lifetimeIncome: Double
    var lifetimeExpenses: Double
    var categoryBreakdown: [String: Double]
    var filteredTransactions: [Transaction]
    var onAddCard: () -> Void
    var onAddTransaction: () -> Void
    var onNewCategory: (String) -> Void
    var onSyncTransaction: (Transaction) -> Void
    var onSyncCard: (CardInfo) -> Void
    var onAdjustBalance: (Transaction) -> Void

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                CardCarousel(
                    cards: cards,
                    selectedIndex: $selectedCardIndex,
                    shimmerOffset: shimmerOffset,
                    onAdd: onAddCard
                )

                PeriodPicker(selectedPeriod: $selectedPeriod)

                HStack(spacing: 14) {
                    MetricCard(title: "Income (all time)", amount: lifetimeIncome, icon: "arrow.down.right.circle.fill", tint: Palette.accentAlt)
                    MetricCard(title: "Expenses (all time)", amount: -lifetimeExpenses, icon: "arrow.up.right.circle.fill", tint: Palette.accent)
                }

                SnapshotCard(
                    title: "Spending Overview",
                    subtitle: selectedPeriod.title,
                    income: totalIncome,
                    expenses: totalExpenses,
                        onViewAll: { showTransactionsSheet = true },
                        onAdd: onAddTransaction
                    )

                    TransactionsCard(transactions: filteredTransactions, onAdd: onAddTransaction)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
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
            AllTransactionsSheet(transactions: transactions, onAdd: onAddTransaction)
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionSheet(
                categories: categories,
                onSave: { newTransaction in
                    var tx = newTransaction
                    if tx.cardId == nil, cards.indices.contains(selectedCardIndex) {
                        tx.cardId = cards[selectedCardIndex].id
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
}

struct PlaceholderTab: View {
    var title: String
    var body: some View {
        ZStack {
            AnimatedBackground()
            Text("\(title) coming soon")
                .foregroundColor(Palette.primary.opacity(0.8))
                .font(.headline)
                .padding()
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.stroke, lineWidth: 1))
        }
    }
}

// MARK: - Settings / Support
struct SettingsTab: View {
    @EnvironmentObject private var session: SessionManager
    @Binding var categories: [String]
    @Binding var requireCardUnlock: Bool
    @Binding var supportTickets: [SupportTicket]
    @Binding var showSupportSheet: Bool
    var onToggleCardLock: (Bool) -> Void

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(spacing: 18) {
                    settingsCard
                    categoriesCard
                    supportCard
                }
                .padding()
            }
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Personalize")
                    .font(.title2.bold())
                    .foregroundColor(Palette.primary)
                Spacer()
            }
            Text("Data syncs automatically from the dashboard. Balances and transactions pull from the server when you open the app.")
                .font(.caption)
                .foregroundColor(Palette.secondary)
                .padding(.bottom, 6)
            Toggle(isOn: $requireCardUnlock) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Require Face ID for cards")
                        .foregroundColor(Palette.primary)
                    Text("Keeps card details locked until you authenticate.")
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                }
            }
            .tint(Palette.accent)
            .onChange(of: requireCardUnlock) { _, newValue in
                onToggleCardLock(newValue)
            }

            Button {
                session.logout()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Log out")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Palette.accentAlt, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: Palette.accentAlt.opacity(0.3), radius: 12, y: 6)
            }

            Button(role: .destructive) {
                Task {
                    if let userId = session.user?.id {
                        try? await APIClient.shared.deleteAccount(userId: userId)
                    }
                    await MainActor.run {
                        session.logout()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.minus")
                    Text("Delete account")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
                .shadow(color: Color.red.opacity(0.15), radius: 10, y: 6)
            }
        }
        .padding()
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Categories")
                    .font(.headline)
                    .foregroundColor(Palette.primary)
                Spacer()
                if !categories.isEmpty {
                    Button {
                        categories.removeAll()
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Palette.mutedFill, in: Capsule())
                            .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            if categories.isEmpty {
                Text("No categories yet. Add from the transaction sheet.")
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
            } else {
                let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(categories, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.mutedFill, in: Capsule())
                            .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Support tickets")
                    .font(.title3.bold())
                    .foregroundColor(Palette.primary)
                Spacer()
                Button {
                    showSupportSheet = true
                } label: {
                    Label("New ticket", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Palette.accentAlt, in: Capsule())
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 10) {
                ForEach(supportTickets) { ticket in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ticket.subject)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Palette.primary)
                        }
                        Spacer()
                        Text(ticket.status.rawValue.capitalized)
                            .font(.caption.weight(.bold))
                            .foregroundColor(ticket.status == .open ? Palette.accent : Palette.accentAlt)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Palette.mutedFill, in: Capsule())
                    }
                    .padding()
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.stroke, lineWidth: 1))
                }
                if supportTickets.isEmpty {
                    Text("No tickets yet. Create one to reach support.")
                        .font(.footnote)
                        .foregroundColor(Palette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
            }
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }
}

private struct SupportTicketSheet: View {
    var onSubmit: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var detail = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Subject")) {
                    TextField("Issue title", text: $subject)
                }
                Section(header: Text("Details")) {
                    TextField("Describe the issue", text: $detail, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("New ticket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit(subject.trimmingCharacters(in: .whitespacesAndNewlines),
                                 detail.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Cards Tab
struct CardsTab: View {
    @Binding var cards: [CardInfo]
    var requireCardUnlock: Bool
    @Binding var locked: Bool
    @Binding var showAddCardSheet: Bool
    var unlock: () -> Void
    var onSelect: (CardInfo) -> Void
    var onSyncCard: (CardInfo) -> Void
    var onDeleteCard: (CardInfo) -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Cards")
                            .font(.largeTitle.bold())
                            .foregroundColor(Palette.primary)
                        Spacer()
                        Button {
                            showAddCardSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Card")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                LinearGradient(colors: [Palette.accentAlt.opacity(0.9), Palette.accent.opacity(0.8)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                            .foregroundColor(.white)
                            .shadow(color: Palette.accentAlt.opacity(0.3), radius: 10, y: 5)
                        }
                        .foregroundColor(.white)
                    }

                    if cards.isEmpty {
                        EmptyStateView(
                            title: "No cards added",
                            message: "Add a card to track balances. Numbers are masked and sensitive fields are not stored."
                        )
                    } else if locked {
                        VStack(spacing: 12) {
                            Text("Secure Access Required")
                                .font(.headline)
                                .foregroundColor(Palette.primary)
                            Text("Authenticate with Face ID/Passcode to view your cards.")
                                .font(.subheadline)
                                .foregroundColor(Palette.secondary)
                            Button {
                                unlock()
                            } label: {
                                Label("Unlock", systemImage: "lock.open.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 18)
                                    .background(Palette.accentAlt, in: Capsule())
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.stroke, lineWidth: 1))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(cards) { card in
                                CardDetailRow(card: card, currencyCode: currencyCode)
                                    .onTapGesture { onSelect(card) }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if !requireCardUnlock {
                locked = false
            } else {
                unlock()
            }
        }
    }
}

private struct CardDetailRow: View {
    var card: CardInfo
    var currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.nickname.isEmpty ? "Card" : card.nickname)
                    .font(.headline)
                    .foregroundColor(Palette.primary)
                Spacer()
            }
            if let balance = card.balance {
                HStack {
                    Text("Balance")
                        .foregroundColor(Palette.secondary)
                    Spacer()
                    Text(balance, format: .currency(code: currencyCode))
                        .foregroundColor(Palette.primary)
                        .font(.subheadline.weight(.semibold))
                }
            }
            if let limit = card.limit {
                HStack {
                    Text("Limit")
                        .foregroundColor(Palette.secondary)
                    Spacer()
                    Text(limit, format: .currency(code: currencyCode))
                        .foregroundColor(Palette.primary)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.stroke, lineWidth: 1))
    }
}

// MARK: - Animated Background
struct AnimatedBackground: View {
    @State private var move = false
    @State private var hueShift: Angle = .degrees(0)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.07, blue: 0.18),
                    Color(red: 0.06, green: 0.12, blue: 0.26),
                    Color(red: 0.03, green: 0.08, blue: 0.20)
                ],
                startPoint: move ? .topLeading : .bottomTrailing,
                endPoint: move ? .bottomTrailing : .topLeading
            )
            .animation(.easeInOut(duration: 30).repeatForever(autoreverses: true), value: move)

            AngularGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.22, green: 0.64, blue: 0.92).opacity(0.15),
                    Color(red: 0.36, green: 0.48, blue: 0.96).opacity(0.15),
                    Color(red: 0.22, green: 0.64, blue: 0.92).opacity(0.15)
                ]),
                center: .center
            )
            .opacity(0.8)
            .blur(radius: 140)
            .rotationEffect(.degrees(move ? 360 : 0))
            .animation(.linear(duration: 80).repeatForever(autoreverses: false), value: move)

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.28, green: 0.74, blue: 0.98).opacity(0.26),
                    Color(red: 0.44, green: 0.48, blue: 0.92).opacity(0.20),
                    .clear.opacity(0.0)
                ]),
                center: move ? .bottomLeading : .topTrailing,
                startRadius: 80,
                endRadius: 720
            )
            .blur(radius: 240)
            .animation(.easeInOut(duration: 18).repeatForever(autoreverses: true), value: move)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.white.opacity(0.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .opacity(0.6)
        }
        .hueRotation(hueShift)
        .onAppear {
            move.toggle()
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: true)) {
                hueShift = .degrees(10)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Header / Carousel
struct CardCarousel: View {
    var cards: [CardInfo]
    @Binding var selectedIndex: Int
    var shimmerOffset: CGFloat
    var onAdd: () -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        if cards.isEmpty {
            VStack(spacing: 14) {
                Button(action: onAdd) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Palette.accentAlt)
                        Text("Add your first card")
                            .font(.headline)
                            .foregroundColor(Palette.primary)
                        Text("Tap to add and start tracking spend.")
                            .font(.caption)
                            .foregroundColor(Palette.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
                }
            }
            .frame(height: 240)
        } else {
            VStack(spacing: 8) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                        CardHeader(card: card, shimmerOffset: shimmerOffset)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 240)
                .padding(.vertical, 2)

                HStack(spacing: 6) {
                    ForEach(0..<cards.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == selectedIndex ? Palette.primary.opacity(0.4) : Palette.primary.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}

private struct CardHeader: View {
    var card: CardInfo
    var shimmerOffset: CGFloat
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.10, green: 0.14, blue: 0.32),
                            Color(red: 0.07, green: 0.26, blue: 0.52),
                            Color(red: 0.11, green: 0.16, blue: 0.36),
                            Color(red: 0.16, green: 0.22, blue: 0.46)
                        ]),
                        center: .center
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Palette.accent.opacity(0.9),
                                    Palette.accentAlt.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.4
                        )
                        .blur(radius: 0.2)
                )
                .shadow(color: Palette.accentAlt.opacity(0.28), radius: 24, x: 0, y: 16)
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.3), .white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(RoundedRectangle(cornerRadius: 24))
                    .offset(x: shimmerOffset)
                    .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: false), value: shimmerOffset)
                )
                .background(
                    RadialGradient(
                        colors: [Palette.accentAlt.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 340
                    )
                    .blur(radius: 50)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(card.nickname.isEmpty ? "Debit Card" : card.nickname)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(card.balance ?? 0, format: .currency(code: currencyCode))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                }

                HStack(spacing: 10) {
                    if let limit = card.limit {
                        StatPill(title: "Limit", value: limit, currencyCode: currencyCode)
                    } else {
                        StatPill(title: "Status", label: "Active")
                    }
                    Spacer()
                }
            }
            .padding(22)
        }
        .padding(.horizontal, 10)
    }
}

private struct StatPill: View {
    var title: String
    var value: Double?
    var currencyCode: String = "USD"
    var label: String?
    var highlight: Bool = false

    init(title: String, value: Double? = nil, currencyCode: String = "USD", label: String? = nil, highlight: Bool = false) {
        self.title = title
        self.value = value
        self.currencyCode = currencyCode
        self.label = label
        self.highlight = highlight
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
            if let value = value {
                Text(value, format: .currency(code: currencyCode))
                    .font(.caption2.monospacedDigit())
            } else if let label = label {
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundColor(.white.opacity(highlight ? 0.95 : 0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: highlight
                    ? [Palette.accentAlt.opacity(0.45), Palette.accent.opacity(0.3)]
                    : [.white.opacity(0.12), .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(highlight ? 0.38 : 0.22), lineWidth: 1)
        )
    }
}

private struct OverviewHeader: View {
    var netBalance: Double
    var income: Double
    var expenses: Double
    var shimmerOffset: CGFloat
    var onAdd: () -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Palette.accent,
                            Palette.accentAlt
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Palette.stroke, lineWidth: 1.2)
                )
                .shadow(color: Palette.accent.opacity(0.35), radius: 18, x: 0, y: 12)
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.25), .white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(RoundedRectangle(cornerRadius: 22))
                    .offset(x: shimmerOffset)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: false), value: shimmerOffset)
                )
                .rotation3DEffect(.degrees(0), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TrackIt")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Daily finance pulse")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    Button(action: onAdd) {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("Net Balance")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(netBalance, format: .currency(code: currencyCode))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}
}

// MARK: - Metric Cards
struct MetricCard: View {
    var title: String
    var amount: Double
    var icon: String
    var tint: Color
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                Spacer()
                Text(amount, format: .currency(code: currencyCode))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Palette.primary)
            }
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundColor(Palette.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Palette.card,
                    Palette.card.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Palette.mutedFill, radius: 8, x: 0, y: 8)
    }
}

// MARK: - Period Picker
struct PeriodPicker: View {
    @Binding var selectedPeriod: Period

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Period.allCases, id: \.self) { period in
                    PeriodPill(period: period, isSelected: period == selectedPeriod) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedPeriod = period
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }
}
private struct PeriodPill: View {
    var period: Period
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Text(period.title)
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(isSelected ? Palette.accent.opacity(0.18) : Palette.mutedFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Palette.accent : Palette.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .foregroundColor(Palette.primary)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .onTapGesture(perform: onTap)
    }
}

// MARK: - Spending Snapshot
struct SnapshotCard: View {
    var title: String
    var subtitle: String
    var income: Double
    var expenses: Double
    var onViewAll: () -> Void
    var onAdd: () -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Palette.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onViewAll) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.rectangle")
                            Text("View all")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            LinearGradient(colors: [Palette.accentAlt.opacity(0.9), Palette.accent.opacity(0.8)],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundColor(.white)
                        .shadow(color: Palette.accentAlt.opacity(0.3), radius: 10, y: 5)
                    }
                }
            }

            ProgressRow(
                title: "Income",
                value: income,
                maxValue: max(income, expenses, 1),
                tint: Palette.accentAlt
            )
            ProgressRow(
                title: "Expenses",
                value: expenses,
                maxValue: max(income, expenses, 1),
                tint: Palette.accent
            )
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }
}

// MARK: - Recent Transactions
struct TransactionsCard: View {
    var transactions: [Transaction]
    var onAdd: () -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.headline)
                    .foregroundColor(Palette.primary)
                Spacer()
                Button {
                    onAdd()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        LinearGradient(colors: [Palette.accentAlt.opacity(0.9), Palette.accent.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .foregroundColor(.white)
                    .shadow(color: Palette.accentAlt.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
            }

            if transactions.isEmpty {
                EmptyStateView(
                    title: "No transactions yet",
                    message: "Tap Add to log your first expense or income."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.category)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Palette.primary)
                                Text(dateFormatter.string(from: transaction.date))
                                    .font(.caption)
                                    .foregroundColor(Palette.secondary)
                            }
                            Spacer()
                            Text("\(transaction.kind == .income ? "+" : "-")\(abs(transaction.amount), format: .currency(code: currencyCode))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(transaction.kind == .income ? Palette.accentAlt : Palette.accent)
                        }
                        .padding(.vertical, 12)

                        if transaction.id != transactions.last?.id {
                            Divider().background(Palette.stroke)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }
}

struct EmptyStateView: View {
    var title: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Palette.primary)
            Text(message)
                .font(.footnote)
                .foregroundColor(Palette.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.mutedFill, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Progress Row
struct ProgressRow: View {
    var title: String
    var value: Double
    var maxValue: Double
    var tint: Color
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundColor(Palette.primary)
                Spacer()
                Text(value, format: .currency(code: currencyCode))
                    .foregroundColor(Palette.secondary)
                    .font(.footnote.weight(.medium))
            }
            GeometryReader { proxy in
                let ratio = maxValue == 0 ? 0 : value / maxValue
                RoundedRectangle(cornerRadius: 10)
                    .fill(Palette.mutedFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(tint.gradient)
                            .frame(width: proxy.size.width * CGFloat(min(ratio, 1)))
                            .animation(.easeInOut(duration: 0.4), value: value)
                    }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Simple Wrap Layout
struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    var items: Data
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 6
    @ViewBuilder var content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generate(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if width + d.width > geo.size.width {
                            width = 0
                            height += d.height + rowSpacing
                        }
                        let result = width
                        width += d.width + spacing
                        return result
                    }
                    .alignmentGuide(.top) { _ in height }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self) { totalHeight = $0 }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Support Ticket Model
struct SupportTicket: Identifiable {
    enum Status: String { case open, pending, closed }
    var id: UUID = UUID()
    var subject: String
    var detail: String
    var status: Status = .open
}
