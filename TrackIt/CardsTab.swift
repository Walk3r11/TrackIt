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
    private let currencyCode = "EUR"

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
                            .shadow(color: Palette.accentAlt.opacity(0.2), radius: 8, y: 4)
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
                                unlock(true)
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
                        LazyVStack(spacing: 12) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                                CardDetailRow(card: card, currencyCode: currencyCode, index: idx, isOverLimit: overLimitCardIds.contains(card.id))
                                    .onTapGesture { onSelect(card) }
                            }
                        }
                    }
                }
                .frame(maxWidth: LayoutMetrics.maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            if !requireCardUnlock {
                locked = false
            }
        }
    }
}

private struct CardDetailRow: View {
    var card: CardInfo
    var currencyCode: String
    var index: Int
    var isOverLimit: Bool
    private var theme: CardTheme.Theme { CardTheme.theme(for: card, index: index) }

    var body: some View {
        let strokeColors = isOverLimit ? [Color.red.opacity(0.95), Color.orange.opacity(0.7)] : theme.stroke
        let glowColor = isOverLimit ? Color.red : theme.glow
        let limits = card.effectiveLimitsInDisplayOrder()

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
            ForEach(limits, id: \.period) { entry in
                HStack {
                    Text("\(entry.period.title) Limit")
                        .foregroundColor(isOverLimit ? Color.red.opacity(0.9) : Palette.secondary)
                    Spacer()
                    Text(entry.limit, format: .currency(code: currencyCode))
                        .foregroundColor(isOverLimit ? Color.red : Palette.primary)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: theme.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
                .overlay(
                    Group {
                        if isOverLimit {
                            RadialGradient(
                                colors: [Color.red.opacity(0.30), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                            .blendMode(.screen)
                            .blur(radius: 4)
                            .mask(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: strokeColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: glowColor.opacity(0.15), radius: 12, y: 6)
    }
}
