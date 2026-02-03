import SwiftUI

struct SummaryCardPager: View {
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

    var body: some View {
        VStack(spacing: 12) {
            SummarySwitcher(
                selectedIndex: $selectedIndex,
                showSavings: showSavings
            )

            ZStack {
                if selectedIndex == 0 {
                    TotalBalanceSummaryCard(
                        periodTitle: dashboardPeriodTitle,
                        amountText: totalBalanceText,
                        cardsCount: cardsCount,
                        averageSpentText: averageSpentText
                    )
                } else {
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
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        }
    }
}

private struct SummarySwitcher: View {
    @Binding var selectedIndex: Int
    var showSavings: Bool

    var body: some View {
        HStack(spacing: 8) {
            SummarySwitchButton(
                title: "Balance",
                isSelected: selectedIndex == 0,
                action: { selectedIndex = 0 }
            )
            SummarySwitchButton(
                title: showSavings ? "Savings" : "Add savings",
                isSelected: selectedIndex == 1,
                action: { selectedIndex = 1 }
            )
        }
    }
}

private struct SummarySwitchButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appFont(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(isSelected ? Palette.accent : Palette.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Palette.card : Palette.cardAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Palette.accent.opacity(0.4) : Palette.stroke,
                            lineWidth: 1
                        )
                )
                .shadow(color: isSelected ? Palette.shadow : .clear, radius: 6, x: 3, y: 4)
                .shadow(color: isSelected ? Palette.highlight : .clear, radius: 6, x: -3, y: -3)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98, pressedOpacity: 0.9))
    }
}
