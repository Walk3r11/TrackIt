import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let change: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.appFont(size: 11, weight: .semibold))
                    .foregroundColor(Palette.secondary)
                    .textCase(.uppercase)
                    .kerning(0.6)

                Spacer()

                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: icon)
                            .font(.appFont(size: 12, weight: .semibold))
                            .foregroundColor(color)
                    )
            }

            Text(value)
                .font(.appFont(size: 20, weight: .bold))
                .foregroundColor(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let change = change {
                ChangeIndicator(change: change)
            }
        }
        .padding(14)
        .minimalSurface(cornerRadius: 16, fill: Palette.card)
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.appFont(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appFont(size: 13, weight: .semibold))
                    .foregroundColor(Palette.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(.appFont(size: 12, weight: .semibold))
                    .foregroundColor(Palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(12)
        .minimalSurface(cornerRadius: 14, fill: Palette.card)
    }
}

struct ChangeIndicator: View {
    let change: Double

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.appFont(size: 10, weight: .bold))
            Text(abs(change).formattedAsPercentage())
                .font(.appFont(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(change >= 0 ? Palette.success : Palette.danger)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((change >= 0 ? Palette.success : Palette.danger).opacity(0.14))
        )
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 16) {
        StatCard(
            title: "Total Income",
            value: "€5,000.00",
            icon: "arrow.down.circle.fill",
            color: Palette.success,
            change: 12.5
        )

        StatRow(
            icon: "chart.bar.fill",
            title: "Daily Average",
            value: "€150.00",
            iconColor: Palette.accent
        )
    }
    .padding()
    .background(Palette.background)
}
