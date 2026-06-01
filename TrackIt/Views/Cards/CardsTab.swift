import SwiftUI

struct CardsTab: View {
    @Binding var cards: [CardInfo]
    var requireCardUnlock: Bool
    @Binding var locked: Bool
    @Binding var showAddCardSheet: Bool
    var overLimitCardIds: Set<UUID> = []
    var unlock: (_ userInitiated: Bool) -> Void
    var onSelect: (CardInfo) -> Void
    var onSyncCard: (CardInfo) -> Void
    var onDeleteCard: (CardInfo) -> Void

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if cards.isEmpty {
                        emptyState
                    } else if locked {
                        lockedState
                    } else {
                        cardsList
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
        }
        .onAppear {
            if !requireCardUnlock {
                locked = false
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Cards")
                    .font(.appFont(size: 26, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                Text("Balances and spending limits")
                    .font(.appFont(size: 13))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer()

            Button {
                showAddCardSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add")
                        .font(.appFont(size: 13, weight: .semibold))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .minimalSurface(cornerRadius: 16, fill: Palette.primary, stroke: Palette.primary)
                .foregroundColor(.white)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No cards yet")
                .font(.appFont(size: 16, weight: .semibold))
            Text("Add a card to track balances and keep limits in sight.")
                .font(.appFont(size: 13))
                .foregroundStyle(Palette.secondary)
            Button("Add your first card") {
                showAddCardSheet = true
            }
            .font(.appFont(size: 13, weight: .semibold))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .minimalSurface(cornerRadius: 20)
    }

    private var lockedState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cards are locked")
                .font(.appFont(size: 16, weight: .semibold))
            Text("Authenticate with Face ID or your passcode to reveal balances.")
                .font(.appFont(size: 13))
                .foregroundStyle(Palette.secondary)

            Button {
                unlock(true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open")
                    Text("Unlock cards")
                        .font(.appFont(size: 13, weight: .semibold))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .minimalSurface(cornerRadius: 14, fill: Palette.primary, stroke: Palette.primary)
                .foregroundColor(.white)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .minimalSurface(cornerRadius: 20)
    }

    private var cardsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                CardRow(card: card, index: idx, isOverLimit: overLimitCardIds.contains(card.id))
                    .onTapGesture { onSelect(card) }
            }
        }
    }
}

private struct CardRow: View {
    var card: CardInfo
    var index: Int
    var isOverLimit: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(card.nickname.isEmpty ? "Card" : card.nickname)
                    .font(.appFont(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                Spacer()
                if isOverLimit {
                    Text("Over limit")
                        .font(.appFont(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.danger)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Palette.danger.opacity(0.12))
                        )
                }
            }

            if let balance = card.balance {
                HStack {
                    Text("Balance")
                        .font(.appFont(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.secondary)
                    Spacer()
                    Text(balance, format: .currency(code: AppConstants.Currency.code))
                        .font(.appFont(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                }
            }

            ForEach(card.effectiveLimitsInDisplayOrder(), id: \.period) { entry in
                HStack {
                    Text("\(entry.period.title) limit")
                        .font(.appFont(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.secondary)
                    Spacer()
                    Text(entry.limit, format: .currency(code: AppConstants.Currency.code))
                        .font(.appFont(size: 12, weight: .semibold))
                        .foregroundStyle(isOverLimit ? Palette.danger : Palette.primary)
                }
            }
        }
        .padding(16)
        .minimalSurface(cornerRadius: 18)
    }
}
