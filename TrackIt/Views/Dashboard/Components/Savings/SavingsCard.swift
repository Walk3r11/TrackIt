import SwiftUI

struct SavingsCard: View {
    var periodTitle: String
    var income: Double
    var expenses: Double
    var goalAmount: Double
    var onEditGoal: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Savings")
                    .font(.headline.weight(.bold))
                    .foregroundColor(Palette.primary)

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Palette.secondary)
                        .frame(width: 32, height: 32)
                        .background(Palette.cardAlt, in: Circle())
                        .overlay(Circle().stroke(Palette.stroke, lineWidth: 1))
                        .contentShape(Circle())
                }
                .frame(width: 44, height: 44)
                .buttonStyle(PressableButtonStyle())
            }

            Text(periodTitle)
                .font(.caption.weight(.semibold))
                .foregroundColor(Palette.secondary)

            let saved = max(income - expenses, 0)
            Text(saved.formattedAsCurrency())
                .font(.appFont(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if goalAmount > 0 {
                let progress = min(max(saved / goalAmount, 0), 1)
                SavingsProgressBar(
                    title: "Goal \(goalAmount.formattedAsCurrency())",
                    progress: progress
                )
            } else {
                Text("Set a goal to track progress.")
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Button(action: onEditGoal) {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                    Text(goalAmount > 0 ? "Edit goal" : "Set goal")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(Palette.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20, tint: [Palette.cardAlt, Palette.card], shadowColor: Palette.shadowStrong)
    }
}
