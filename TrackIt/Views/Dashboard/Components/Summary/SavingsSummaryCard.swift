import SwiftUI

struct SavingsSummaryCard: View {
    var savedAmount: Double
    var savedText: String
    var periodTitle: String
    var goalAmount: Double
    var goalAmountText: String
    var goalProgress: Double?
    var onOpen: () -> Void
    var onRemove: () -> Void

    var body: some View {
        let remaining = max(goalAmount - savedAmount, 0)
        let progress = min(max(goalProgress ?? 0, 0), 1)

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("Savings")
                        .font(.appFont(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(Palette.secondary)

                    Text(periodTitle)
                        .font(.appFont(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Palette.primary.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Palette.cardAlt)
                        )
                        .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
                }

                Text(savedText)
                    .font(.appFont(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if goalAmount > 0 {
                    let progressTitle = savedAmount >= goalAmount
                        ? "Goal reached • \(goalAmountText)"
                        : "\(remaining.formattedAsCurrency()) left • Goal \(goalAmountText)"
                    SavingsProgressBar(title: progressTitle, progress: progress)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Set a goal to track progress.")
                        .font(.appFont(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Palette.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onOpen) {
                Image(systemName: "target")
                    .font(.appFont(size: 15, weight: .semibold))
                    .foregroundColor(Palette.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Palette.card)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .padding(.trailing, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 140)
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            onOpen()
        }
    }
}

// MARK: - Savings Progress Indicator

private struct SavingsProgressIndicator: View {
    let progress: Double

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.cardAlt)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.accent)
                .frame(width: nil)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: CGFloat(progress), y: 1, anchor: .leading)
        }
        .frame(height: 10)
    }
}
