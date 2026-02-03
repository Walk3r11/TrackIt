import SwiftUI

struct AverageSpentPill: View {
    var valueText: String

    var body: some View {
        HStack(spacing: 5) {
            Text("Avg spent")
                .font(.appFont(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Palette.tertiary)
            Text(valueText)
                .font(.appFont(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Palette.cardAlt)
        )
        .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
    }
}
