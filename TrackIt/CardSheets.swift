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
            Form {
                Section(header: Text("Details")) {
                    Picker("Type", selection: $kind) {
                        Text("Select Type").tag(nil as Transaction.Kind?)
                        Text("Expense").tag(Transaction.Kind.expense as Transaction.Kind?)
                        Text("Income").tag(Transaction.Kind.income as Transaction.Kind?)
                    }
                    .foregroundColor(kind == nil ? Palette.warning : Palette.primary)
                    
                    if showKindWarning {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Palette.warning)
                            Text("Please select a transaction type!")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Palette.warning)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Category", text: $category)
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
                                                .background(Color.secondary.opacity(0.12), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Text(timeZoneInfo(for: date))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            Form {
                Section(header: Text("Card details")) {
                    TextField("Nickname", text: $nickname)
                }
                Section(header: Text("Balance")) {
                    TextField("Current balance", text: $balanceText)
                        .keyboardType(.decimalPad)
                    SectionHeaderRow(title: "Spending limits")
                    TextField("Daily limit", text: $dailyLimitText)
                        .keyboardType(.decimalPad)
                    TextField("Weekly limit", text: $weeklyLimitText)
                        .keyboardType(.decimalPad)
                    TextField("Monthly limit", text: $monthlyLimitText)
                        .keyboardType(.decimalPad)
                    TextField("Tags (comma separated)", text: $tagsText)
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
                            fieldCard(title: "Card details") {
                                LabeledField(title: "Nickname", placeholder: "Debit Card", text: $nickname)
                            }

                            fieldCard(title: "Balance") {
                                LabeledField(
                                    title: "Current balance",
                                    placeholder: "0.00",
                                    text: $balanceText,
                                    keyboard: .decimalPad
                                )
                            }

                            fieldCard(title: "Spending limits") {
                                LabeledField(title: "Daily limit", placeholder: "0.00", text: $dailyLimitText, keyboard: .decimalPad)
                                LabeledField(title: "Weekly limit", placeholder: "0.00", text: $weeklyLimitText, keyboard: .decimalPad)
                                LabeledField(title: "Monthly limit", placeholder: "0.00", text: $monthlyLimitText, keyboard: .decimalPad)
                            }

                            fieldCard(title: "Tags") {
                                LabeledField(title: "Comma separated", placeholder: "food, travel, business", text: $tagsText)
                            }

                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Delete card")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                                .foregroundColor(Palette.danger)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.cardAlt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Palette.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.cardAlt.opacity(0.95), in: Capsule())
                .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
                .buttonStyle(PressableButtonStyle())

            Spacer()

            Text("Card Details")
                .font(.headline.weight(.bold))
                .foregroundColor(Palette.primary)

            Spacer()

            Button("Save") { save() }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [Palette.accentAlt, Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
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

    private func fieldCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondary)

            VStack(spacing: 12) {
                content()
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 20, tint: [Palette.accentAlt, Palette.accent], shadowColor: Palette.accentAlt, darkOverlayOpacity: 0.12)
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

private struct SectionHeaderRow: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
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
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.primary.opacity(0.9))

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#if canImport(UIKit)
                .keyboardType(keyboard)
#endif
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.cardAlt.opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.stroke, lineWidth: 1))
                .foregroundStyle(Palette.primary)
        }
    }
}
