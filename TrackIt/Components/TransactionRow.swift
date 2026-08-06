import SwiftUI

struct TransactionRow: View, Equatable {
    var title: String
    var subtitle: String
    var amountText: String
    var tint: Color


    private var categoryColor: Color {
        CategoryColors.color(for: title)
    }

    private var icon: String {
        iconName(for: title)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Palette.cardAlt)
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundColor(categoryColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.appFont(size: 14, weight: .semibold))
                    .foregroundColor(Palette.primary)
                Text(subtitle)
                    .font(.appFont(size: 12, weight: .medium))
                    .foregroundColor(Palette.secondary)
            }

            Spacer()

            Text(amountText)
                .font(.appFont(size: 14, weight: .bold))
                .foregroundColor(tint)
        }
        .padding(.vertical, 12)
        .drawingGroup()
    }

    static func == (lhs: TransactionRow, rhs: TransactionRow) -> Bool {
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.amountText == rhs.amountText &&
        lhs.tint == rhs.tint
    }

    private func iconName(for category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("food") || lower.contains("restaurant") || lower.contains("cafe") { return "fork.knife" }
        if lower.contains("rent") || lower.contains("home") { return "house.fill" }
        if lower.contains("uber") || lower.contains("taxi") || lower.contains("transport") { return "car.fill" }
        if lower.contains("shopping") || lower.contains("amazon") { return "bag.fill" }
        if lower.contains("salary") || lower.contains("pay") { return "creditcard.fill" }
        return "circle.fill"
    }
}
