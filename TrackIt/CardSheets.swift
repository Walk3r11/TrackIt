import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    var categories: [String]
    var onSave: (Transaction) -> Void
    var onNewCategory: (String) -> Void
    @State private var amountText: String = ""
    @State private var category: String = ""
    @State private var kind: Transaction.Kind = .expense
    @State private var date: Date = .now

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
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
                    Picker("Type", selection: $kind) {
                        Text("Expense").tag(Transaction.Kind.expense)
                        Text("Income").tag(Transaction.Kind.income)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
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
        Double(amountText) != nil && !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let rawAmount = Double(amountText) else { return }
        let amount = kind == .income ? abs(rawAmount) : -abs(rawAmount)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = Transaction(amount: amount, category: trimmedCategory, date: date, kind: kind)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            if !categories.contains(where: { $0.caseInsensitiveCompare(trimmedCategory) == .orderedSame }) {
                onNewCategory(trimmedCategory)
            }
            onSave(transaction)
        }
        dismiss()
    }
}

struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (CardInfo) -> Void
    @State private var nickname: String = ""
    @State private var limitText: String = ""
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
                    TextField("Limit", text: $limitText)
                        .keyboardType(.decimalPad)
                    TextField("Tags (comma separated)", text: $tagsText)
                }
                Section(footer: Text("For security, only the last 4 digits are stored. Full card number and CVC are discarded after saving.")) {
                    EmptyView()
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
        let card = CardInfo(
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            limit: Double(limitText),
            balance: Double(balanceText),
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        onSave(card)
        dismiss()
    }
}

struct CardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var card: CardInfo
    var onUpdate: (CardInfo) -> Void
    var onDelete: () -> Void

    @State private var nickname: String = ""
    @State private var limitText: String = ""
    @State private var balanceText: String = ""
    @State private var tagsText: String = ""

    init(card: CardInfo, onUpdate: @escaping (CardInfo) -> Void, onDelete: @escaping () -> Void) {
        self.card = card
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _nickname = State(initialValue: card.nickname)
        _limitText = State(initialValue: card.limit.map { String($0) } ?? "")
        _balanceText = State(initialValue: card.balance.map { String($0) } ?? "")
        _tagsText = State(initialValue: (card.tags ?? []).joined(separator: ", "))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card details")) {
                    TextField("Nickname", text: $nickname)
                }

                Section(header: Text("Balance")) {
                    TextField("Current balance", text: $balanceText)
                        .keyboardType(.decimalPad)
                    TextField("Limit", text: $limitText)
                        .keyboardType(.decimalPad)
                    TextField("Tags (comma separated)", text: $tagsText)
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Card", systemImage: "trash")
                    }
                }

                Section(footer: Text("Card numbers and CVC are not stored.")) { EmptyView() }
            }
            .navigationTitle("Card Details")
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
        return !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let updated = CardInfo(
            id: card.id,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            limit: Double(limitText),
            balance: Double(balanceText),
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        onUpdate(updated)
        dismiss()
    }
}
