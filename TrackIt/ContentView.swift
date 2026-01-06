import SwiftUI
import LocalAuthentication
#if canImport(UIKit)
import UIKit
#endif

enum LayoutMetrics {
    static let maxContentWidth: CGFloat = 420
    static let horizontalPadding: CGFloat = 16
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var selectedPeriod: Period = .daily
    @State private var shimmerOffset: CGFloat = -300
    @State private var showAddSheet = false
    @State private var showAddCardSheet = false
    @State private var selectedCardDetail: CardInfo?
    @AppStorage("requireCardUnlock") private var requireCardUnlock = true
    @State private var cardsLocked = true
    @State private var selectedCardIndex = 0
    @State private var transactions: [Transaction] = []
    @State private var categories: [String] = []
    @State private var cards: [CardInfo] = []
    @State private var showCardDailyLimitAlert = false
    @State private var cardDailyLimitAlertCard: CardInfo?
    @State private var cardDailyLimitAlertSpent: Double = 0
    @State private var cardLimitAlertPeriod: SpendingLimitPeriod = .daily
    @State private var lastLocallyAddedTransactionId: UUID?
    @State private var supportTickets: [SupportTicket] = []
    @State private var showSupportSheet = false
    @State private var showTransactionsSheet = false
    @State private var cardUnlockInProgress = false
    @State private var showCardsManagerSheet = false
    @State private var isLoadingCards = false
    @State private var isLoadingTransactions = false
    @State private var isLoadingCategories = false
    @State private var isLoadingSavings = false
    @State private var isLoadingTickets = false
    @State private var cardsLoaded = false
    @State private var transactionsLoaded = false
    @State private var categoriesLoaded = false
    @State private var savingsLoaded = false
    @State private var ticketsLoaded = false
    @State private var isRefreshing = false

var body: some View {
    applyRootModifiers(to: mainTabs)
}

private func applyRootModifiers<Content: View>(to content: Content) -> some View {
    let view0 = content
        .preferredColorScheme(.dark)
        .appBackground()
        .animation(.easeInOut(duration: 0.25), value: selectedTab)

	        let view1 = view0.onAppear {
	            loadPersistedData()
	            cardsLocked = requireCardUnlock
	            refreshFromServer()
	            checkSelectedCardDailyLimit()
	            DispatchQueue.main.async { [self] in
	                updateFilteredTransactionsCacheSync()
	            }
	        }

        let view2 = view1.task(id: session.user?.id) {
            refreshFromServer()
        }

        let view3 = view2.task(id: session.token) {
            refreshFromServer()
        }

        let view4 = view3
            .onChange(of: session.user?.id ?? "") { _, _ in
                refreshFromServer()
            }
            .onChange(of: session.token ?? "") { _, _ in
                refreshFromServer()
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 0 {
                    refreshFromServer()
                }
            }

	        let view5 = view4
	        .onChange(of: cards) { _, newCards in
	            if newCards.isEmpty {
	                selectedCardIndex = 0
	            } else if selectedCardIndex >= newCards.count {
	                selectedCardIndex = max(0, newCards.count - 1)
	            }
	            saveCards()
	            checkSelectedCardDailyLimit()
	        }
	            .onChange(of: transactions.count) { _, _ in
	                saveTransactions()
	                checkSelectedCardDailyLimit()
	            }
	            .onChange(of: selectedCardIndex) { _, _ in
	                checkSelectedCardDailyLimit()
	                DispatchQueue.main.async { [self] in
	                    updateFilteredTransactionsCacheSync()
	                }
	            }
	            .onChange(of: selectedPeriod) { _, _ in
	                DispatchQueue.main.async { [self] in
	                    updateFilteredTransactionsCacheSync()
	                }
	            }
	            .onChange(of: transactions.count) { _, _ in
	                DispatchQueue.main.async { [self] in
	                    updateFilteredTransactionsCacheSync()
	                }
	            }
	            .onChange(of: showAddSheet) { _, isPresented in
	                if !isPresented {
	                    checkLimitAfterLocalTransactionAdd()
	                }
	            }
            .onChange(of: categories) { _, _ in
                saveCategories()
            }

	    let view6 = view5
	        .onChange(of: requireCardUnlock) { _, enabled in
	            cardsLocked = enabled
	        }

    let view7 = view6.onChange(of: scenePhase) { _, newPhase in
        if newPhase == .background && requireCardUnlock {
            cardsLocked = true
        } else if newPhase == .active {
            refreshFromServer()
        }
    }

    let view8 = view7.sheet(item: $selectedCardDetail) { card in
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

    let view9 = view8.sheet(isPresented: $showSupportSheet) {
        SupportTicketSheet { subject, detail in
            guard let userId = session.user?.id, let token = session.token else { return }
            let ticket = SupportTicket(subject: subject, detail: detail)
            let ticketId = ticket.id
            supportTickets.insert(ticket, at: 0)
            
            Task {
                do {
                    try await APIClient.shared.createTicket(
                        userId: userId,
                        subject: subject,
                        initialMessage: detail,
                        token: token
                    )
                    print("✅ Ticket created successfully")
                } catch {
                    await MainActor.run {
                        supportTickets.removeAll { $0.id == ticketId }
                        print("❌ Failed to create ticket: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

	    let view10 = view9.alert("Spending limit exceeded", isPresented: $showCardDailyLimitAlert) {
	        Button("Edit limit") {
	            if let cardDailyLimitAlertCard {
	                selectedCardDetail = cardDailyLimitAlertCard
	            }
	        }
	        Button("OK", role: .cancel) {}
	    } message: {
	        Text(cardDailyLimitAlertMessage)
	    }

	    let view11 = view10.sheet(isPresented: $showCardsManagerSheet) {
	        CardsTab(
	            cards: $cards,
	            requireCardUnlock: requireCardUnlock,
	            locked: $cardsLocked,
	            showAddCardSheet: $showAddCardSheet,
	            overLimitCardIds: overLimitCardIds,
	            unlock: { userInitiated in
	                authenticateCards(userInitiated: userInitiated)
	            },
	            onSelect: { card in
	                selectedCardDetail = card
	            },
	            onSyncCard: { card in syncCard(card) },
	            onDeleteCard: { card in deleteCard(card) }
	        )
	    }
	
	    return view11
	}

	    private var mainTabs: some View {
	        TabView(selection: $selectedTab) {
	            dashboard
	                .tag(0)
	                .tabItem { Label("Home", systemImage: "house.fill") }
	                .onAppear {
	                    refreshFromServer()
	                }

	            AIChatTab()
	                .tag(1)
	                .tabItem { Label("Assistant", systemImage: "wand.and.stars") }
	                .environmentObject(session)

	            InsightsTab(
	                transactions: $transactions,
	                cards: $cards,
	                selectedPeriod: $selectedPeriod
	            )
	            .tag(2)
	            .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
	            .environmentObject(session)

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
    }

    private var cardDailyLimitAlertMessage: String {
        let currencyCode = "EUR"
        let spentText = cardDailyLimitAlertSpent.formatted(.currency(code: currencyCode))
        let limitValue = cardDailyLimitAlertCard?.effectiveLimit(for: cardLimitAlertPeriod) ?? 0
        let limitText = limitValue.formatted(.currency(code: currencyCode))
        let nickname = cardDailyLimitAlertCard?.nickname.isEmpty == false ? cardDailyLimitAlertCard?.nickname ?? "Card" : "Card"
        let period = cardLimitAlertPeriod
        return "You spent \(spentText) this \(period.title.lowercased()) on \(nickname), over your limit of \(limitText)."
    }

    private var overLimitCardIds: Set<UUID> {
        let now = Date()
        var overLimit: Set<UUID> = []
        for card in cards {
            guard let primaryLimit = card.primaryLimitForDisplay() else { continue }
            let (period, limit) = primaryLimit
            let start = periodStart(for: period, now: now)
            let spent = spend(for: card.id, since: start)
            if spent >= limit {
                print("⚠️ Card \(card.nickname) (\(card.id.uuidString.prefix(8))) is over limit:")
                print("   Period: \(period.rawValue), Limit: \(limit), Spent: \(spent)")
                print("   Period start: \(start)")
                overLimit.insert(card.id)
            }
        }
        return overLimit
    }

    private func checkSelectedCardDailyLimit() {
        let now = Date()
        for card in cards {
            for period in [SpendingLimitPeriod.daily, .weekly, .monthly] {
                guard let limit = card.effectiveLimit(for: period), limit > 0 else { continue }
                let start = periodStart(for: period, now: now)
                let spent = spend(for: card.id, since: start)
                guard spent >= limit else { continue }

                let signature = "\(periodKey(from: start))|\(period.rawValue)|\(Int((limit * 100).rounded()))"
                if storedCardLimitSignature(for: card.id, period: period) == signature { continue }
                storeCardLimitSignature(signature, for: card.id, period: period)

                cardDailyLimitAlertCard = card
                cardDailyLimitAlertSpent = spent
                cardLimitAlertPeriod = period
                triggerLimitExceededHaptics()
                showCardDailyLimitAlert = true
                return
            }
        }
    }

    private func checkLimitAfterLocalTransactionAdd() {
        guard let txId = lastLocallyAddedTransactionId else { return }
        lastLocallyAddedTransactionId = nil

        guard let tx = transactions.first(where: { $0.id == txId }) else { return }
        guard tx.kind == .expense else { return }

        guard let card = cardForTransaction(tx) else { return }

        for period in [SpendingLimitPeriod.daily, .weekly, .monthly] {
            guard let limit = card.effectiveLimit(for: period), limit > 0 else { continue }
            let start = periodStart(for: period, now: tx.date)
            let spent = spend(for: card.id, since: start)
            guard spent >= limit else { continue }

            let key = "cardLimitAlertLastTx.\(card.id.uuidString).\(period.rawValue).\(periodKey(from: start))"
            if UserDefaults.standard.string(forKey: key) == tx.id.uuidString { continue }
            UserDefaults.standard.set(tx.id.uuidString, forKey: key)

            cardDailyLimitAlertCard = card
            cardDailyLimitAlertSpent = spent
            cardLimitAlertPeriod = period
            triggerLimitExceededHaptics()
            showCardDailyLimitAlert = true
            return
        }
    }

    private func cardForTransaction(_ tx: Transaction) -> CardInfo? {
        if let cardId = tx.cardId {
            return cards.first(where: { $0.id == cardId })
        }
        if cards.count == 1 { return cards.first }
        return nil
    }
    
    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func spend(for cardId: UUID, since start: Date) -> Double {
        let includeUnassigned = cards.count == 1 && cards.first?.id == cardId
        let calendar = utcCalendar()
        
        let normalizedStart = calendar.startOfDay(for: start)
        let now = Date()
        let normalizedNow = calendar.startOfDay(for: now)
        
        let maxDate = normalizedNow.addingTimeInterval(86400)
        
        let matchingTransactions = transactions.filter {
            guard $0.kind == .expense else { return false }
            
            let cardMatches: Bool
            if let txCardId = $0.cardId {
                cardMatches = txCardId == cardId
            } else {
                cardMatches = includeUnassigned
            }
            guard cardMatches else { return false }
            
            let txDateStart = calendar.startOfDay(for: $0.date)
            
            guard txDateStart >= normalizedStart else { return false }
            
            guard txDateStart <= maxDate else { return false }
            
            return true
        }
        
        let total = matchingTransactions.reduce(0) { $0 + abs($1.amount) }
        
        if !matchingTransactions.isEmpty {
            let oldestTx = matchingTransactions.min(by: { $0.date < $1.date })
            if let oldest = oldestTx, oldest.date < normalizedStart {
                print("⚠️ WARNING: Counting transaction from before period start!")
                print("   Period start: \(normalizedStart), Oldest TX: \(oldest.date)")
            }
        }
        
        return total
    }

    private func periodStart(for period: SpendingLimitPeriod, now: Date) -> Date {
        let calendar = utcCalendar()
        
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

    private func periodKey(from start: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start)
    }

    private func storedCardLimitSignature(for cardId: UUID, period: SpendingLimitPeriod) -> String {
        UserDefaults.standard.string(forKey: "cardLimitAlertSignature.\(cardId.uuidString).\(period.rawValue)") ?? ""
    }

    private func storeCardLimitSignature(_ signature: String, for cardId: UUID, period: SpendingLimitPeriod) {
        UserDefaults.standard.set(signature, forKey: "cardLimitAlertSignature.\(cardId.uuidString).\(period.rawValue)")
    }

    private func triggerLimitExceededHaptics() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
#endif
    }

	    private func refreshFromServer() {
	        guard !isRefreshing else {
	            print("⚠️ refreshFromServer: Already refreshing, skipping")
	            return
	        }
	        
	        guard let userId = session.user?.id else {
	            print("⚠️ refreshFromServer: No user ID")
	            if cards.isEmpty {
	                restoreCardsFromDisk()
	            }
	            if transactions.isEmpty {
	                restoreTransactionsFromDisk()
	            }
	            return
	        }
	        
	        let token = session.token
	        print("🔄 refreshFromServer: Starting refresh for userId: \(userId), hasToken: \(token != nil)")
	        
	        isRefreshing = true
	        
	        cardsLoaded = false
	        transactionsLoaded = false
	        categoriesLoaded = false
	        savingsLoaded = false
	        ticketsLoaded = false
	        isLoadingCards = true
	        isLoadingTransactions = true
	        isLoadingCategories = true
	        isLoadingSavings = true
	        isLoadingTickets = true
	        
	        Task {
	            if let token = token, !session.sessionValidated {
	                do {
	                    _ = try await APIClient.shared.validateSession(token: token)
	                    print("✅ Session validated")
	                    await MainActor.run {
	                        session.sessionValidated = true
	                    }
	                } catch {
	                    print("❌ Session validation failed: \(error.localizedDescription)")
						
						if let apiError = error as? APIError,
						   case .requestFailed(let message) = apiError,
						   (message.contains("401") || message.contains("Unauthorized") || message.contains("invalid session")) {
							await MainActor.run {
								session.logout()
							}
							return
						}
						
	                    await MainActor.run {
	                        isLoadingCards = false
	                        isLoadingTransactions = false
	                        isLoadingCategories = false
	                        isLoadingSavings = false
	                        isLoadingTickets = false
	                        isRefreshing = false
	                        if self.cards.isEmpty {
	                            restoreCardsFromDisk()
	                        }
	                        if self.transactions.isEmpty {
	                            restoreTransactionsFromDisk()
	                        }
	                    }
	                    return
	                }
	            } else if token == nil {
	                print("⚠️ No token provided for refresh")
	                await MainActor.run {
	                    isRefreshing = false
	                }
	                return
	            }
	            
	            async let cardsTask = APIClient.shared.fetchCards(userId: userId, token: token)
	            async let transactionsTask = APIClient.shared.fetchTransactions(userId: userId, token: token)
	            async let categoriesTask = APIClient.shared.fetchCategories(userId: userId, token: token)
	            async let savingsTask = APIClient.shared.fetchSavingsGoal(userId: userId, token: token)
	            async let ticketsTask = APIClient.shared.fetchTickets(userId: userId, token: token)
	            
	            let remoteCards = try? await cardsTask
	            await MainActor.run {
	                isLoadingCards = false
	                cardsLoaded = remoteCards != nil
	                if let cards = remoteCards {
	                    print("✅ Cards loaded: \(cards.count) cards")
	                } else {
	                    print("❌ Cards failed to load")
	                }
	            }
	            
	            let remoteTx = try? await transactionsTask
	            await MainActor.run {
	                isLoadingTransactions = false
	                transactionsLoaded = remoteTx != nil
	                if let tx = remoteTx {
	                    print("✅ Transactions loaded: \(tx.count) transactions")
	                } else {
	                    print("❌ Transactions failed to load")
	                }
	            }
	            
	            let remoteCategories = try? await categoriesTask
	            await MainActor.run {
	                isLoadingCategories = false
	                categoriesLoaded = remoteCategories != nil
	                if let categories = remoteCategories {
	                    print("✅ Categories loaded: \(categories.count) categories")
	                } else {
	                    print("❌ Categories failed to load")
	                }
	            }
	            
	            let remoteSavings = try? await savingsTask
	            await MainActor.run {
	                isLoadingSavings = false
	                savingsLoaded = remoteSavings != nil
	                if let savings = remoteSavings {
	                    print("✅ Savings loaded: \(savings.goalAmount)")
	                } else {
	                    print("❌ Savings failed to load")
	                }
	            }
	            
	            let remoteTickets = try? await ticketsTask
	            await MainActor.run {
	                isLoadingTickets = false
	                ticketsLoaded = remoteTickets != nil
	                if let tickets = remoteTickets {
	                    print("✅ Tickets loaded: \(tickets.count) tickets")
	                } else {
	                    print("❌ Tickets failed to load")
	                }
	            }
	            
	            await MainActor.run {
	                if let cards = remoteCards, !cards.isEmpty {
	                    self.cards = mergeCardsPreservingOrder(remote: cards, local: self.cards)
	                    saveCards()
	                } else if self.cards.isEmpty {
	                    restoreCardsFromDisk()
	                }
	                
	                if let transactions = remoteTx, !transactions.isEmpty {
	                    let normalized = attachSingleCardId(transactions)
	                    let merged = mergeTransactionsWithLocal(normalized)
	                    self.transactions = merged
	                    saveTransactions()
	                } else if self.transactions.isEmpty {
	                    restoreTransactionsFromDisk()
	                }
	                
	                if let categories = remoteCategories {
	                    self.categories = categories
	                    saveCategories()
	                }
	                
                if let savings = remoteSavings {
                    if savings.goalAmount > 0 {
	                        UserDefaults.standard.set(true, forKey: "showSavingsCard")
	                    }
	                    NotificationCenter.default.post(
	                        name: NSNotification.Name("SavingsGoalUpdated"),
	                        object: nil,
	                        userInfo: ["goalAmount": savings.goalAmount, "goalPeriod": savings.goalPeriod.rawValue]
	                    )
	                }
	                
	                if let tickets = remoteTickets {
	                    if !tickets.isEmpty {
	                        self.supportTickets = tickets
	                    } else {
	                        print("⚠️ Tickets API returned empty array, keeping existing tickets")
					}
				} else {
					print("⚠️ Tickets failed to load, keeping existing tickets")
				}
	                
	                self.isRefreshing = false
	            }
	        }
	    }

    private var dashboard: some View {
        let income = totalIncome
        let net = netBalance
        let breakdown = categoryBreakdown
        let incomeBreakdown = incomeCategoryBreakdown
        let filtered = filteredTransactions
        let name = session.user?.firstName.isEmpty == false ? (session.user?.firstName ?? "there") : "there"

        return ZStack(alignment: .topTrailing) {
            HomeDashboard(
                userId: session.user?.id,
	            firstName: name,
	            selectedPeriod: $selectedPeriod,
	            shimmerOffset: $shimmerOffset,
	            transactions: $transactions,
	            showAddSheet: $showAddSheet,
	            cardsLocked: $cardsLocked,
	            showAddCardSheet: $showAddCardSheet,
	            cards: $cards,
	            overLimitCardIds: overLimitCardIds,
	            selectedCardIndex: $selectedCardIndex,
	            showTransactionsSheet: $showTransactionsSheet,
	            categories: categories,
            netBalance: net,
            totalIncome: income,
            totalExpenses: totalExpensesMagnitude,
            lifetimeIncome: lifetimeIncome,
            lifetimeExpenses: lifetimeExpensesMagnitude,
            incomeCategoryBreakdown: incomeBreakdown,
            expenseCategoryBreakdown: breakdown,
            filteredTransactions: filtered,
	            onAddCard: { showAddCardSheet = true },
            onAddTransaction: {
                if cards.isEmpty {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        showAddCardSheet = true
                    }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        showAddSheet = true
                    }
                }
            },
            onNewCategory: { name in
                addCategoryIfNeeded(name)
                syncCategoryRemote(name)
            },
	            onSyncTransaction: { tx in
	                lastLocallyAddedTransactionId = tx.id
	                syncTransaction(tx)
	            },
	            onSyncCard: { card in syncCard(card) },
	            onAdjustBalance: { tx in adjustBalance(for: tx) },
	            onOpenCards: {
	                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
	                    showCardsManagerSheet = true
	                }
	            }
	        )
        }
    }

    private func authenticateCards(userInitiated: Bool) {
        if !requireCardUnlock {
            cardsLocked = false
            return
        }
        guard !cards.isEmpty else {
            cardsLocked = false
            return
        }
        guard !cardUnlockInProgress else { return }
        cardUnlockInProgress = true

        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your cards") { success, _ in
                DispatchQueue.main.async {
                    cardsLocked = !success
                    cardUnlockInProgress = false
                }
            }
        } else {
            cardsLocked = false
            cardUnlockInProgress = false
        }
    }

    @State private var cachedFilteredIndices: [Int] = []
    @State private var cachedTotalIncome: Double = 0
    @State private var cachedTotalExpenses: Double = 0
    @State private var cachedCategoryBreakdown: [String: Double] = [:]
    @State private var cachedIncomeCategoryBreakdown: [String: Double] = [:]
    @State private var cachedLifetimeIncome: Double = 0
    @State private var cachedLifetimeExpenses: Double = 0
    @State private var cachePeriod: Period = .monthly
    @State private var cacheCardIndex: Int = 0
    @State private var cacheTransactionCount: Int = 0

    private var periodStart: Date {
        let calendar = Calendar.current
        let now = Date()
        switch selectedPeriod {
        case .daily:
            return calendar.startOfDay(for: now)
        case .weekly:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        case .biweekly:
            return calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now)) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: now)) ?? now
        case .quarterly:
            return calendar.date(byAdding: .month, value: -3, to: calendar.startOfDay(for: now)) ?? now
        case .semiannual:
            return calendar.date(byAdding: .month, value: -6, to: calendar.startOfDay(for: now)) ?? now
        case .nineMonth:
            return calendar.date(byAdding: .month, value: -9, to: calendar.startOfDay(for: now)) ?? now
        case .yearly:
            return calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: now)) ?? now
        }
    }

    private var selectedCardId: UUID? {
        cards.indices.contains(selectedCardIndex) ? cards[selectedCardIndex].id : nil
    }

    private var filteredTransactions: [Transaction] {
        if cachedFilteredIndices.isEmpty {
            return []
        }
        return cachedFilteredIndices.map { transactions[$0] }
    }

    private func updateFilteredTransactionsCache() {
        DispatchQueue.main.async { [self] in
            updateFilteredTransactionsCacheSync()
        }
    }
    
    private func updateFilteredTransactionsCacheSync() {
        let needsUpdate = cachePeriod != selectedPeriod || 
                         cacheCardIndex != selectedCardIndex || 
                         cacheTransactionCount != transactions.count ||
                         cachedFilteredIndices.isEmpty
        
        guard needsUpdate else { return }
        
        var indices: [Int] = []
        let periodStartDate = periodStart
        let calendar = Calendar.current
        
        
        for (index, tx) in transactions.enumerated() {
            let txDateStart = calendar.startOfDay(for: tx.date)
            let periodStartNormalized = calendar.startOfDay(for: periodStartDate)
            
            guard txDateStart >= periodStartNormalized else { continue }
            
            if let cardId = selectedCardId {
                if tx.cardId == cardId {
                    indices.append(index)
                } else if tx.cardId == nil {
                    let allUnassigned = transactions.allSatisfy { $0.cardId == nil }
                    if cards.count == 1 || allUnassigned {
                        indices.append(index)
                    }
                }
            } else {
                indices.append(index)
            }
        }
        
        cachePeriod = selectedPeriod
        cacheCardIndex = selectedCardIndex
        cacheTransactionCount = transactions.count
        cachedFilteredIndices = indices
        
        var income: Double = 0
        var expenses: Double = 0
        var expenseBreakdown: [String: Double] = [:]
        var incomeBreakdown: [String: Double] = [:]
        
        for index in indices {
            let tx = transactions[index]
            if tx.kind == .income {
                income += tx.amount
                incomeBreakdown[tx.category, default: 0] += abs(tx.amount)
            } else {
                expenses += abs(tx.amount)
                expenseBreakdown[tx.category, default: 0] += abs(tx.amount)
            }
        }
        
        cachedTotalIncome = income
        cachedTotalExpenses = expenses
        cachedCategoryBreakdown = expenseBreakdown
        cachedIncomeCategoryBreakdown = incomeBreakdown
        
        if cacheTransactionCount != transactions.count {
            cachedLifetimeIncome = 0
            cachedLifetimeExpenses = 0
            for tx in transactions {
                if tx.kind == .income {
                    cachedLifetimeIncome += tx.amount
                } else {
                    cachedLifetimeExpenses += abs(tx.amount)
                }
            }
        }
    }

    private var lifetimeIncome: Double {
        return cachedLifetimeIncome
    }

    private var lifetimeExpensesMagnitude: Double {
        return cachedLifetimeExpenses
    }

    private var totalIncome: Double {
        return cachedTotalIncome
    }

    private var totalExpensesMagnitude: Double {
        return cachedTotalExpenses
    }

    private var netBalance: Double {
        return cachedTotalIncome - cachedTotalExpenses
    }

    private var categoryBreakdown: [String: Double] {
        return cachedCategoryBreakdown
    }

    private var incomeCategoryBreakdown: [String: Double] {
        return cachedIncomeCategoryBreakdown
    }

	    private func loadPersistedData() {
        restoreCardsFromDisk()
        restoreTransactionsFromDisk()
        restoreCategoriesFromDisk()
        restoreTicketsFromDisk()

	        refreshFromServer()
    }
    
    @MainActor
    private func restoreTicketsFromDisk() {
        if let storedTickets: [SupportTicket] = SecureStore.load([SupportTicket].self, key: "supportTickets"), !storedTickets.isEmpty {
            supportTickets = storedTickets
        }
    }

	    @MainActor
	    private func restoreCardsFromDisk() {
	        if let storedCards: [CardInfo] = SecureStore.load([CardInfo].self, key: "cards"), !storedCards.isEmpty {
	            cards = storedCards
	        }
	    }

	    private func mergeCardsPreservingOrder(remote: [CardInfo], local: [CardInfo]) -> [CardInfo] {
	        guard !local.isEmpty else { return remote }
	        let remoteById = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
	        var result: [CardInfo] = []
	        result.reserveCapacity(remote.count)
	        for c in local {
	            if let r = remoteById[c.id] {
	                result.append(r)
	            }
	        }
	        for r in remote where !result.contains(where: { $0.id == r.id }) {
	            result.append(r)
	        }
	        return result
	    }

    @MainActor
    private func restoreTransactionsFromDisk() {
        if let storedTransactions: [Transaction] = SecureStore.load([Transaction].self, key: "transactions") {
            transactions = storedTransactions
        }
    }

    @MainActor
    private func attachSingleCardId(_ remote: [Transaction]) -> [Transaction] {
        guard cards.count == 1, let cardId = cards.first?.id else { return remote }
        return remote.map { tx in
            guard tx.cardId == nil else { return tx }
            var updated = tx
            updated.cardId = cardId
            return updated
        }
    }

    @MainActor
    private func mergeTransactionsWithLocal(_ remote: [Transaction]) -> [Transaction] {
        let localMap = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        return remote.map { tx in
            guard tx.cardId == nil, let local = localMap[tx.id], let cardId = local.cardId else { return tx }
            var updated = tx
            updated.cardId = cardId
            return updated
        }
    }

    @MainActor
    private func restoreCategoriesFromDisk() {
        if let storedCategories: [String] = SecureStore.load([String].self, key: "categories") {
            categories = storedCategories
        } else {
            categories = ["Dining", "Groceries", "Travel", "Bills", "Shopping", "Transfers"]
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

    private func syncCategoryRemote(_ name: String) {
        guard let userId = session.user?.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                let remote = try await APIClient.shared.createCategory(userId: userId, name: trimmed)
                await MainActor.run {
                    categories = remote
                    saveCategories()
                    refreshFromServer()
                }
            } catch {
            }
        }
    }

    private func syncCard(_ card: CardInfo) {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                try await APIClient.shared.saveCard(userId: userId, card: card)
                await MainActor.run {
                    refreshFromServer()
                }
            } catch {
            }
        }
    }

    private func syncTransaction(_ tx: Transaction) {
        guard let userId = session.user?.id else { return }
        var outbound = tx
        if outbound.cardId == nil {
            if cards.count == 1 {
                outbound.cardId = cards.first?.id
            } else if cards.indices.contains(selectedCardIndex) {
                outbound.cardId = cards[selectedCardIndex].id
            }
        }
        guard outbound.cardId != nil else {
            return
        }
        Task {
            do {
                try await APIClient.shared.saveTransaction(userId: userId, transaction: outbound)
                await MainActor.run {
                    refreshFromServer()
                }
            } catch {
            }
        }
    }

    private func updateCardRemote(_ card: CardInfo) {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                try await APIClient.shared.updateCard(userId: userId, card: card)
                await MainActor.run {
                    refreshFromServer()
                }
            } catch {
            }
        }
    }

    private func deleteCardRemote(_ card: CardInfo) {
        guard let userId = session.user?.id else { return }
        Task {
            do {
                try await APIClient.shared.deleteCard(userId: userId, cardId: card.id)
                await MainActor.run {
                    refreshFromServer()
                }
            } catch {
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


// MARK: - Background
struct AnimatedBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.06),
                        Color(red: 0.02, green: 0.03, blue: 0.08),
                        Color(red: 0.01, green: 0.01, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LiquidBlob(
                    time: t,
                    baseX: 0.25,
                    baseY: 0.22,
                    radius: 260,
                    colors: [Palette.accentAlt, Palette.accent],
                    opacity: 0.22
                )

                LiquidBlob(
                    time: t + 2.4,
                    baseX: 0.80,
                    baseY: 0.32,
                    radius: 230,
                    colors: [Color(red: 0.60, green: 0.38, blue: 0.92), Palette.accentAlt],
                    opacity: 0.18
                )

                LiquidBlob(
                    time: t + 5.1,
                    baseX: 0.55,
                    baseY: 0.88,
                    radius: 320,
                    colors: [Color(red: 0.28, green: 0.70, blue: 0.78), Palette.accent],
                    opacity: 0.16
                )

                LiquidBlob(
                    time: t + 7.8,
                    baseX: 0.10,
                    baseY: 0.78,
                    radius: 240,
                    colors: [Color(red: 0.90, green: 0.30, blue: 0.48), Palette.accentAlt],
                    opacity: 0.14
                )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.02)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.62)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)
            }
            .ignoresSafeArea()
        }
    }
}

private struct LiquidBlob: View {
    var time: TimeInterval
    var baseX: CGFloat
    var baseY: CGFloat
    var radius: CGFloat
    var colors: [Color]
    var opacity: Double = 0.20
    var saturation: Double = 0.55

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let x = size.width * baseX + sin(time * 0.35) * (size.width * 0.10)
            let y = size.height * baseY + cos(time * 0.30) * (size.height * 0.10)
            let blur = max(40, radius * 0.4)

            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: colors + colors),
                        center: .center
                    )
                )
                .frame(width: radius, height: radius)
                .position(x: x, y: y)
                .blur(radius: blur)
                .saturation(saturation)
                .opacity(opacity)
                .blendMode(.screen)
        }
    }
}

// MARK: - Header
struct CardCarousel: View {
    var cards: [CardInfo]
    @Binding var selectedIndex: Int
    var shimmerOffset: CGFloat
    var overLimitCardIds: Set<UUID> = []
    var onAdd: () -> Void
    private let currencyCode = "EUR"

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
                        CardHeader(card: card, shimmerOffset: shimmerOffset, index: idx, isOverLimit: overLimitCardIds.contains(card.id))
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
    var index: Int
    var isOverLimit: Bool
    private let currencyCode = "EUR"
    private var theme: CardTheme.Theme { CardTheme.theme(for: card, index: index) }

    var body: some View {
        let strokeColors = isOverLimit ? [Color.red.opacity(0.95), Color.orange.opacity(0.7)] : theme.stroke
        let glowColor = isOverLimit ? Color.red : theme.glow
        let limitAccent = isOverLimit ? Color.red : theme.accent
        let primaryLimit = card.primaryLimitForDisplay()
        let limitTitle = primaryLimit.map { "\($0.period.title) Limit" }

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: theme.background,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: strokeColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.4
                        )
                        .blur(radius: 0.2)
                )
	                .overlay(
	                    Group {
	                        if isOverLimit {
                                RadialGradient(
                                    colors: [Color.red.opacity(0.35), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 200
                                )
                                .blendMode(.screen)
                                .blur(radius: 6)
                                .mask(RoundedRectangle(cornerRadius: 24))
	                        }
	                    }
	                )
                .shadow(color: glowColor.opacity(0.22), radius: 16, x: 0, y: 10)
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
                    Group {
                        if isOverLimit {
                            RadialGradient(
                                colors: [glowColor.opacity(0.25), .clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 200
                            )
                        } else {
                            RadialGradient(
                                colors: [glowColor.opacity(0.20), .clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 200
                            )
                        }
                    }
                    .blur(radius: 20)
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
                    if let primaryLimit {
                        StatPill(title: limitTitle ?? "Limit", value: primaryLimit.limit, currencyCode: currencyCode, highlight: isOverLimit, accentColor: limitAccent)
                    } else {
                        StatPill(title: "Status", label: "Active", accentColor: theme.accent)
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
    var currencyCode: String = "EUR"
    var label: String?
    var highlight: Bool = false
    var accentColor: Color? = nil

    init(title: String, value: Double? = nil, currencyCode: String = "EUR", label: String? = nil, highlight: Bool = false, accentColor: Color? = nil) {
        self.title = title
        self.value = value
        self.currencyCode = currencyCode
        self.label = label
        self.highlight = highlight
        self.accentColor = accentColor
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
                colors: accentColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: highlight ? Color.red.opacity(0.40) : .clear, radius: 12, x: 0, y: 7)
        .shadow(color: highlight ? Color.red.opacity(0.20) : .clear, radius: 22, x: 0, y: 12)
    }

    private var accentColors: [Color] {
        if let accentColor = accentColor {
            return [
                accentColor.opacity(0.55),
                accentColor.opacity(0.32)
            ]
        }
        if highlight {
            return [Color.red.opacity(0.60), Color.orange.opacity(0.22)]
        }
        return [.white.opacity(0.12), .white.opacity(0.05)]
    }

    private var borderColor: Color {
        if let accentColor = accentColor {
            return accentColor.opacity(0.35)
        }
        return .white.opacity(highlight ? 0.38 : 0.22)
    }
}

private struct OverviewHeader: View {
    var netBalance: Double
    var income: Double
    var expenses: Double
    var shimmerOffset: CGFloat
    var onAdd: () -> Void
    private let currencyCode = "EUR"

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

// MARK: - Metrics
struct MetricCard: View {
    var title: String
    var amount: Double
    var icon: String
    var tint: Color
    private let currencyCode = "EUR"

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

// MARK: - Period
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

// MARK: - Snapshot
struct SnapshotCard: View {
    var title: String
    var subtitle: String
    var income: Double
    var expenses: Double
    var incomeCategoryBreakdown: [String: Double]
    var expenseCategoryBreakdown: [String: Double]

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
            }

            SpendingCategoryBar(
                title: "Income",
                total: income,
                breakdown: incomeCategoryBreakdown
            )

            SpendingCategoryBar(
                title: "Expenses",
                total: expenses,
                breakdown: expenseCategoryBreakdown
            )
        }
        .padding()
        .glassCard(cornerRadius: 18, tint: [Palette.accentAlt, Palette.accent], shadowColor: Palette.accentAlt)
    }
}

private struct SpendingCategoryBar: View {
    var title: String
    var total: Double
    var breakdown: [String: Double]

    private let currencyCode = "EUR"

    private var segments: [CategorySegment] {
        let cleaned = breakdown
            .map { (name: $0.key, value: $0.value) }
            .filter { $0.value > 0.0001 }
            .sorted { $0.value > $1.value }

        guard !cleaned.isEmpty else { return [] }

        let maxSegments = 7
        let head = Array(cleaned.prefix(maxSegments))
        let other = cleaned.dropFirst(maxSegments).reduce(0.0) { $0 + $1.value }

        var result = head.map {
            CategorySegment(name: $0.name, value: $0.value, color: CategoryColors.color(for: $0.name))
        }
        if other > 0 {
            result.append(CategorySegment(name: "Other", value: other, color: CategoryColors.color(for: "Other")))
        }
        return result
    }
    
    var body: some View {
        let segmentsTotal = segments.reduce(0.0) { $0 + $1.value }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundColor(Palette.primary)
                Spacer()
                Text(total, format: .currency(code: currencyCode))
                    .foregroundColor(Palette.secondary)
                    .font(.footnote.weight(.medium))
            }

            if segments.isEmpty {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.mutedFill)
                    .frame(height: 12)
            } else {
                SegmentedBar(segments: segments)
                    .frame(height: 12)

                VStack(spacing: 8) {
                    ForEach(segments.prefix(6)) { seg in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(seg.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(seg.color)
                                    .lineLimit(1)
                                Spacer()
                                Text(seg.value, format: .currency(code: currencyCode))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Palette.secondary)
                            }

                            GeometryReader { proxy in
                                let ratio = segmentsTotal == 0 ? 0 : seg.value / segmentsTotal
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Palette.mutedFill)
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(seg.color)
                                            .frame(width: proxy.size.width * CGFloat(min(max(ratio, 0), 1)))
                                    }
                            }
                            .frame(height: 6)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct SegmentedBar: View {
    var segments: [CategorySegment]

    var body: some View {
        let total = segments.reduce(0.0) { $0 + $1.value }
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        GeometryReader { proxy in
            let width = proxy.size.width

            HStack(spacing: 0) {
                ForEach(segments) { seg in
                    Rectangle()
                        .fill(seg.color)
                        .frame(width: total == 0 ? 0 : width * CGFloat(seg.value / total))
                }
            }
            .clipShape(shape)
            .overlay(shape.stroke(Color.white.opacity(0.10), lineWidth: 1))
            .background(Palette.mutedFill, in: shape)
        }
    }
}

private struct CategorySegment: Identifiable {
    var id: String { name }
    var name: String
    var value: Double
    var color: Color
}

// MARK: - Transactions
struct TransactionsCard: View {
    var transactions: [Transaction]
    var onAdd: () -> Void
    private let currencyCode = "EUR"
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
                LazyVStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        TransactionRowView(
                            transaction: transaction,
                            dateFormatter: dateFormatter,
                            currencyCode: currencyCode,
                            showDivider: transaction.id != transactions.last?.id
                        )
                    }
                }
            }
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }
}

private struct TransactionRowView: View {
    let transaction: Transaction
    let dateFormatter: DateFormatter
    let currencyCode: String
    let showDivider: Bool

    var body: some View {
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

        if showDivider {
            Divider().background(Palette.stroke)
        }
    }
}

private struct DashboardHeader: View {
    var name: String
    var netBalance: Double
    var onAdd: () -> Void
    private let currencyCode = "EUR"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Palette.accentAlt.opacity(0.95), Palette.accent.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Palette.accent.opacity(0.35), radius: 12, y: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome back!")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Palette.secondary)
                    Text("Hello, \(name)!")
                        .font(.title3.weight(.bold))
                        .foregroundColor(Palette.primary)
                }
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.12), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Balance")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Text(netBalance, format: .currency(code: currencyCode))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
        .padding(.horizontal)
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

// MARK: - Progress
struct ProgressRow: View {
    var title: String
    var value: Double
    var maxValue: Double
    var tint: Color
    private let currencyCode = "EUR"

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

// MARK: - Layout
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