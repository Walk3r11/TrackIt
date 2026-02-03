import SwiftUI

struct TrendRow: View {
    let title: String
    let current: Double
    let previous: Double
    let icon: String
    let color: Color

    private var change: Double {
        current.percentageChange(from: previous) ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            iconView
            contentView
            Spacer()
            changeView
        }
        .padding(12)
        .minimalSurface(cornerRadius: 14, fill: Palette.card)
    }

    private var iconView: some View {
        Circle()
            .fill(Palette.cardAlt)
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: icon)
                    .font(.appFont(size: 14, weight: .semibold))
                    .foregroundColor(color)
            )
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Palette.primary)

            HStack(spacing: 8) {
                Text("Current: \(current.formattedAsCurrency())")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Palette.secondary)
                Text("Previous: \(previous.formattedAsCurrency())")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Palette.tertiary)
            }
        }
    }

    private var changeView: some View {
        HStack(spacing: 4) {
            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                .font(.caption.weight(.bold))
            Text(abs(change).formattedAsPercentage())
                .font(.caption.weight(.bold))
        }
        .foregroundColor(change >= 0 ? Palette.success : Palette.danger)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill((change >= 0 ? Palette.success : Palette.danger).opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    TrendRow(
        title: "Income Trend",
        current: 5000,
        previous: 4500,
        icon: "arrow.down.circle.fill",
        color: Palette.success
    )
    .padding()
}
