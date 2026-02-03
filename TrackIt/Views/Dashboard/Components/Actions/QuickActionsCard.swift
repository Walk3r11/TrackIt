import SwiftUI

struct QuickActionsCard: View {
    var onAdd: () -> Void
    var onAddCard: () -> Void
    var showAddSavings: Bool = false
    var onAddSavings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick actions")
                .font(.appFont(size: 15, weight: .semibold, design: .serif))
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

                }
            }
        }
        .padding(18)
        .glassCard(
            cornerRadius: 20,
            tint: [Palette.cardAlt, Palette.card],
            shadowColor: Palette.shadow
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Palette.accent)
                .frame(width: 40, height: 3)
                .padding(.top, 10)
                .padding(.leading, 16)
        }
    }
}
