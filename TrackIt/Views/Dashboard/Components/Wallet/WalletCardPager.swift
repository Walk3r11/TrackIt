import SwiftUI

struct WalletCardPager: View {
    var cards: [CardInfo]
    @Binding var selectedCardIndex: Int
    var transactions: [Transaction]
    var overLimitCardIds: Set<UUID> = []
    var onAddCard: () -> Void
    var onOpenCards: () -> Void

    @State private var scrollId: Int?
    @State private var cachedSeries: [UUID: [Double]] = [:]
    @State private var seriesTask: Task<Void, Never>?

    var body: some View {
        if cards.isEmpty {
            EmptyWalletCard(onAdd: onAddCard)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
        } else {
            let cardHeight: CGFloat = 260
            let indicatorHeight: CGFloat = cards.count > 1 ? 18 : 0
            VStack(spacing: 8) {
                GeometryReader { proxy in

                    let screenWidth = proxy.size.width
                    let cardWidth = screenWidth - (LayoutMetrics.horizontalPadding * 2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                                let limitText: String? = card.primaryLimitForDisplay().map { entry in
                                    "\(entry.period.title) \(entry.limit.formattedAsCurrency())"
                                }
                                WalletCard(
                                    title: card.nickname.isEmpty ? "Wallet" : card.nickname,
                                    limitText: limitText,
                                    amountText: (card.balance ?? 0).formattedAsCurrency(),
                                    values: getCachedSeries(cardId: card.id),
                                    isOverLimit: overLimitCardIds.contains(card.id)
                                )
                                .frame(width: cardWidth, height: cardHeight)
                                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                .onTapGesture { onOpenCards() }
                                .id(idx)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $scrollId)
                    .onAppear {
                        scrollId = selectedCardIndex
                        updateCachedSeries()
                    }
                    .onChange(of: transactions) { _, _ in
                        updateCachedSeries()
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
                        seriesTask?.cancel()
                    }
                }
                .frame(height: cardHeight)

                if cards.count > 1 {
                    WalletPageIndicator(currentIndex: selectedCardIndex, totalCount: cards.count)
                }
            }
            .frame(height: cardHeight + indicatorHeight)
        }
    }

    // MARK: - Private Methods

    private func getCachedSeries(cardId: UUID) -> [Double] {
        cachedSeries[cardId] ?? []
    }

    private func updateCachedSeries(for cardIds: [UUID]? = nil) {
        let availableCardIds = Set(cards.map { $0.id })
        cachedSeries = cachedSeries.filter { availableCardIds.contains($0.key) }

        let missingIds: [UUID]
        if let cardIdsOverride = cardIds {
            missingIds = cardIdsOverride.filter { cachedSeries[$0] == nil }
        } else {
            missingIds = availableCardIds.filter { cachedSeries[$0] == nil }
        }

        guard !missingIds.isEmpty else { return }

        let snapshotTransactions = transactions
        let snapshotCards = cards

        seriesTask?.cancel()
        let calc = WalletCalculator.self
        let currentCardsCount = cards.count

        seriesTask = Task {
            var seriesResults: [UUID: [Double]] = [:]
            seriesResults.reserveCapacity(missingIds.count)

            for card in snapshotCards where missingIds.contains(card.id) {
                guard !Task.isCancelled else { return }
                seriesResults[card.id] = calc.dailyNetSeries(
                    transactions: snapshotTransactions,
                    cardId: card.id,
                    days: 12
                )
            }

            guard !Task.isCancelled else { return }
            guard cards.count == currentCardsCount else { return }

            for (id, values) in seriesResults {
                cachedSeries[id] = values
            }
        }
    }
}

private struct WalletPageIndicator: View {
    var currentIndex: Int
    var totalCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Palette.accent : Palette.stroke)
                    .frame(width: index == currentIndex ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentIndex)
        .accessibilityLabel("Cards page \(currentIndex + 1) of \(totalCount)")
    }
}

// MARK: - Wallet Calculator

enum WalletCalculator {
    nonisolated static func dailyNetSeries(transactions: [Transaction], cardId: UUID, days: Int) -> [Double] {
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
