import SwiftUI

struct EmptyWalletCard: View {
    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wallet")
                            .font(.appFont(size: 18, weight: .semibold, design: .serif))
                            .foregroundColor(Palette.primary)
                        Text("Add a card to track balances.")
                            .font(.caption)
                            .foregroundColor(Palette.secondary)
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundColor(Palette.accent)
                        .frame(width: 40, height: 40)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
                        .accessibilityHidden(true)
                }

                HStack(spacing: 10) {
                    Image(systemName: "creditcard.fill")
                        .font(.appFont(size: 14, weight: .bold))
                    Text("Add card")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .opacity(0.9)
                }
                .foregroundColor(Palette.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .glassCard(
                cornerRadius: 26,
                tint: [Palette.cardAlt, Palette.card],
                shadowColor: Palette.shadowStrong
            )
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: 52, height: 4)
                    .padding(.top, 14)
                    .padding(.leading, 18)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Add card")
    }
}
