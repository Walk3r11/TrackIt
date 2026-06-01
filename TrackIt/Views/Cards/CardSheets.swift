import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    var categories: [String]
    var onSave: (Transaction) -> Void
    var onNewCategory: (String) -> Void
    var selectedCardId: UUID?
    @State private var amountText: String = ""
    @State private var category: String = ""
    @State private var kind: Transaction.Kind? = nil
    @State private var date: Date = .now
    @State private var showKindWarning: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        SheetCard("Type") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    kindButton(
                                        title: "Expense",
                                        systemImage: "arrow.down.circle.fill",
                                        value: .expense,
                                        tint: Palette.danger
                                    )
                                    kindButton(
                                        title: "Income",
                                        systemImage: "arrow.up.circle.fill",
                                        value: .income,
                                        tint: Palette.success
                                    )
                                }

                                if showKindWarning {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(Palette.warning)
                                        Text("Please select a transaction type.")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(Palette.warning)
                                    }
                                }
                            }
                        }

                        SheetCard("Details") {
                            VStack(alignment: .leading, spacing: 12) {
                                LabeledField(
                                    title: "Amount",
                                    placeholder: "0.00",
                                    text: $amountText,
                                    keyboard: .decimalPad
                                )

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Palette.primary.opacity(0.9))

                                    TextField("Groceries", text: $category)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled()
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .softInset(cornerRadius: 16)
                                        .foregroundStyle(Palette.primary)

                                    if !categories.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(categories, id: \.self) { item in
                                                    Button {
                                                        category = item
                                                    } label: {
                                                        Text(item)
                                                            .font(.caption.weight(.semibold))
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 8)
                                                            .background(Palette.cardAlt, in: Capsule())
                                                            .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Palette.primary.opacity(0.9))

                                    HStack {
                                        DatePicker("", selection: $date, displayedComponents: .date)
                                            .labelsHidden()
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .softInset(cornerRadius: 16)

                                    Text(timeZoneInfo(for: date))
                                        .font(.footnote)
                                        .foregroundStyle(Palette.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: LayoutMetrics.maxContentWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        parsedAmount != nil && !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && kind != nil
    }

    private var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        if let direct = Double(normalized) { return direct }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: amountText)?.doubleValue
    }

    private func save() {
        guard let rawAmount = parsedAmount else { return }
        guard let transactionKind = kind else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showKindWarning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showKindWarning = false
                }
            }
            return
        }
        let amount = transactionKind == .income ? abs(rawAmount) : -abs(rawAmount)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = Transaction(cardId: selectedCardId, amount: amount, category: trimmedCategory, date: date, kind: transactionKind)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            if !categories.contains(where: { $0.caseInsensitiveCompare(trimmedCategory) == .orderedSame }) {
                onNewCategory(trimmedCategory)
            }
            onSave(transaction)
        }
        dismiss()
    }

    private func timeZoneInfo(for date: Date) -> String {
        let tz = TimeZone.current
        let seconds = tz.secondsFromGMT(for: date)
        let hours = seconds / 3600
        let minutes = abs(seconds / 60) % 60
        let sign = seconds >= 0 ? "+" : "-"
        let offset = String(format: "GMT%@%02d:%02d", sign, abs(hours), minutes)
        let name = tz.identifier
        let abbrev = tz.abbreviation(for: date) ?? offset
        return "Time zone: \(name) (\(abbrev), \(offset))"
    }

    private func kindButton(title: String, systemImage: String, value: Transaction.Kind, tint: Color) -> some View {
        let isSelected = kind == value
        return Button {
            kind = value
            showKindWarning = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.appFont(size: 15, weight: .semibold))
                Text(title)
                    .font(.appFont(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .minimalSurface(cornerRadius: 16, fill: isSelected ? tint.opacity(0.15) : Palette.cardAlt, stroke: isSelected ? tint.opacity(0.35) : Palette.stroke)
            .foregroundColor(isSelected ? tint : Palette.secondary)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (CardInfo) -> Void
    @State private var nickname: String = ""
    @State private var dailyLimitText: String = ""
    @State private var weeklyLimitText: String = ""
    @State private var monthlyLimitText: String = ""
    @State private var balanceText: String = ""
    @State private var tagsText: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        SheetCard("Card details") {
                            LabeledField(title: "Nickname", placeholder: "Debit Card", text: $nickname)
                        }

                        SheetCard("Balance") {
                            LabeledField(
                                title: "Current balance",
                                placeholder: "0.00",
                                text: $balanceText,
                                keyboard: .decimalPad
                            )
                        }

                        SheetCard("Spending limits") {
                            LabeledField(title: "Daily limit", placeholder: "0.00", text: $dailyLimitText, keyboard: .decimalPad)
                            LabeledField(title: "Weekly limit", placeholder: "0.00", text: $weeklyLimitText, keyboard: .decimalPad)
                            LabeledField(title: "Monthly limit", placeholder: "0.00", text: $monthlyLimitText, keyboard: .decimalPad)
                        }

                        SheetCard("Tags") {
                            LabeledField(title: "Comma separated", placeholder: "food, travel, business", text: $tagsText)
                        }

                        Text("Card numbers and CVC are not stored.")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: LayoutMetrics.maxContentWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Add Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let parsedBalance = Self.parseDecimal(balanceText)
        let dailyLimit = Self.parseDecimal(dailyLimitText).flatMap { $0 > 0 ? $0 : nil }
        let weeklyLimit = Self.parseDecimal(weeklyLimitText).flatMap { $0 > 0 ? $0 : nil }
        let monthlyLimit = Self.parseDecimal(monthlyLimitText).flatMap { $0 > 0 ? $0 : nil }

        let provisional = CardInfo(
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            limit: nil,
            limitPeriod: nil,
            dailyLimit: dailyLimit,
            weeklyLimit: weeklyLimit,
            monthlyLimit: monthlyLimit,
            balance: parsedBalance,
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        let legacy = provisional.legacyLimitForAPI()
        let card = CardInfo(
            id: provisional.id,
            nickname: provisional.nickname,
            limit: legacy.limit,
            limitPeriod: legacy.period,
            dailyLimit: provisional.dailyLimit,
            weeklyLimit: provisional.weeklyLimit,
            monthlyLimit: provisional.monthlyLimit,
            balance: provisional.balance,
            tags: provisional.tags
        )
        onSave(card)
        dismiss()
    }

    fileprivate static func parseDecimal(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if let direct = Double(normalized) { return direct }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }
}

struct CardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var card: CardInfo
    var onUpdate: (CardInfo) -> Void
    var onDelete: () -> Void

    @State private var nickname: String = ""
    @State private var dailyLimitText: String = ""
    @State private var weeklyLimitText: String = ""
    @State private var monthlyLimitText: String = ""
    @State private var balanceText: String = ""
    @State private var tagsText: String = ""

    init(card: CardInfo, onUpdate: @escaping (CardInfo) -> Void, onDelete: @escaping () -> Void) {
        self.card = card
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _nickname = State(initialValue: card.nickname)
        _dailyLimitText = State(initialValue: card.effectiveLimit(for: .daily).map { String($0) } ?? "")
        _weeklyLimitText = State(initialValue: card.effectiveLimit(for: .weekly).map { String($0) } ?? "")
        _monthlyLimitText = State(initialValue: card.effectiveLimit(for: .monthly).map { String($0) } ?? "")
        _balanceText = State(initialValue: card.balance.map { String($0) } ?? "")
        _tagsText = State(initialValue: (card.tags ?? []).joined(separator: ", "))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header

                        VStack(spacing: 14) {
                            SheetCard("Card details") {
                                LabeledField(title: "Nickname", placeholder: "Debit Card", text: $nickname)
                            }

                            SheetCard("Balance") {
                                LabeledField(
                                    title: "Current balance",
                                    placeholder: "0.00",
                                    text: $balanceText,
                                    keyboard: .decimalPad
                                )
                            }

                            SheetCard("Spending limits") {
                                LabeledField(title: "Daily limit", placeholder: "0.00", text: $dailyLimitText, keyboard: .decimalPad)
                                LabeledField(title: "Weekly limit", placeholder: "0.00", text: $weeklyLimitText, keyboard: .decimalPad)
                                LabeledField(title: "Monthly limit", placeholder: "0.00", text: $monthlyLimitText, keyboard: .decimalPad)
                            }

                            SheetCard("Tags") {
                                LabeledField(title: "Comma separated", placeholder: "food, travel, business", text: $tagsText)
                            }

                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "trash")
                                        .font(.appFont(size: 14, weight: .bold))
                                    Text("Delete card")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                                .foregroundColor(Palette.danger)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
                            }
                            .buttonStyle(PressableButtonStyle())

                            Text("Card numbers and CVC are not stored.")
                                .font(.footnote)
                                .foregroundStyle(Palette.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: LayoutMetrics.maxContentWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, LayoutMetrics.horizontalPadding)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var canSave: Bool {
        return !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }
                .font(.appFont(size: 13, weight: .semibold))
                .foregroundColor(Palette.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .minimalSurface(cornerRadius: 16, fill: Palette.cardAlt)
                .buttonStyle(PressableButtonStyle())

            Spacer()

            Text("Card Details")
                .font(.appFont(size: 16, weight: .semibold))
                .foregroundColor(Palette.primary)

            Spacer()

            Button("Save") { save() }
                .font(.appFont(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .minimalSurface(cornerRadius: 16, fill: Palette.primary, stroke: Palette.primary)
                .opacity(canSave ? 1 : 0.45)
                .disabled(!canSave)
                .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: LayoutMetrics.maxContentWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func save() {
        let parsedBalance = AddCardSheet.parseDecimal(balanceText)
        let dailyLimit = AddCardSheet.parseDecimal(dailyLimitText).flatMap { $0 > 0 ? $0 : nil }
        let weeklyLimit = AddCardSheet.parseDecimal(weeklyLimitText).flatMap { $0 > 0 ? $0 : nil }
        let monthlyLimit = AddCardSheet.parseDecimal(monthlyLimitText).flatMap { $0 > 0 ? $0 : nil }

        let provisional = CardInfo(
            id: card.id,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            limit: nil,
            limitPeriod: nil,
            dailyLimit: dailyLimit,
            weeklyLimit: weeklyLimit,
            monthlyLimit: monthlyLimit,
            balance: parsedBalance,
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        let legacy = provisional.legacyLimitForAPI()
        let updated = CardInfo(
            id: provisional.id,
            nickname: provisional.nickname,
            limit: legacy.limit,
            limitPeriod: legacy.period,
            dailyLimit: provisional.dailyLimit,
            weeklyLimit: provisional.weeklyLimit,
            monthlyLimit: provisional.monthlyLimit,
            balance: provisional.balance,
            tags: provisional.tags
        )
        onUpdate(updated)
        dismiss()
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

private struct LabeledField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var keyboard: KeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#if canImport(UIKit)
                .keyboardType(keyboard)
#endif
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .minimalSurface(cornerRadius: 16, fill: Palette.card)
                .foregroundStyle(Palette.primary)
        }
    }
}
