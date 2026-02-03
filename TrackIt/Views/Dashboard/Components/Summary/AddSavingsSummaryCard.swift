import SwiftUI

struct AddSavingsSummaryCard: View {
    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("Savings")
                            .font(.appFont(size: 13, weight: .semibold, design: .serif))
                            .foregroundColor(Palette.secondary)
                    }

                    Text("Add savings goal")
                        .font(.appFont(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("Tap to add a goal.")
                        .font(.appFont(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .glassCard(
            cornerRadius: 24,
            tint: [Palette.cardAlt, Palette.card],
            shadowColor: Palette.shadowStrong
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Palette.accent)
                .frame(width: 46, height: 4)
                .padding(.top, 12)
                .padding(.leading, 20)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Add savings goal")
    }
}
