import SwiftUI

struct SavingsGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var goalAmount: Double
    @Binding var goalPeriodRaw: String
    var currentSaved: Double

    @State private var amountText: String = ""

    private var period: SpendingLimitPeriod {
        SpendingLimitPeriod(rawValue: goalPeriodRaw) ?? .monthly
    }

    private var progress: Double {
        goalAmount > 0 ? min(max(currentSaved / goalAmount, 0), 1) : 0
    }

    private var remaining: Double {
        max(goalAmount - currentSaved, 0)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        progressCard
                        goalCard

                        Text("Set this to 0 to disable the goal bar.")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: LayoutMetrics.maxContentWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Savings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        goalAmount = max(0, parseDecimal(amountText) ?? 0)
                        dismiss()
                    }
                }
            }
            .onAppear {
                amountText = goalAmount > 0 ? String(goalAmount) : ""
            }
        }
    }

    // MARK: - Sections

    private var progressCard: some View {
        SheetCard("Progress") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Saved so far (\(period.title))")
                        .foregroundStyle(Palette.secondary)
                    Spacer()
                    Text(currentSaved, format: .currency(code: AppConstants.Currency.code))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.primary)
                }

                if goalAmount > 0 {
                    HStack {
                        Text(currentSaved, format: .currency(code: AppConstants.Currency.code))
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                        Spacer()
                        Text(goalAmount, format: .currency(code: AppConstants.Currency.code))
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                    }

                    ProgressView(value: progress)
                        .tint(Palette.accent)

                    if currentSaved >= goalAmount {
                        Text("Goal reached!")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.success)
                    } else {
                        Text("\(remaining.formattedAsCurrency()) left to reach your goal.")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondary)
                    }
                } else {
                    Text("Set a goal to start tracking progress.")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondary)
                }
            }
        }
    }

    private var goalCard: some View {
        SheetCard("Goal") {
            VStack(alignment: .leading, spacing: 12) {
                GoalField(title: "Goal amount", placeholder: "0.00", text: $amountText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal period")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.primary.opacity(0.9))

                    Picker("Goal period", selection: $goalPeriodRaw) {
                        ForEach(SpendingLimitPeriod.allCases, id: \.self) { p in
                            Text(p.title).tag(p.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: - Helpers

    private func parseDecimal(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if let direct = Double(normalized) { return direct }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }
}

private struct SheetCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)

            VStack(spacing: 12) {
                content
            }
        }
        .padding(14)
        .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
    }
}

private struct GoalField: View {
    var title: String
    var placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)

            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .minimalSurface(cornerRadius: 16, fill: Palette.card)
                .foregroundStyle(Palette.primary)
        }
    }
}
