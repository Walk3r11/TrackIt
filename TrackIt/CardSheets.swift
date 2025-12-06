import SwiftUI
import VisionKit

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
    @State private var number: String = ""
    @State private var limitText: String = ""
    @State private var balanceText: String = ""
    @State private var tagsText: String = ""
    @State private var framePulse = false
    @State private var scanResultHandled = false
    @State private var autoSaveTriggered = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card details")) {
                    TextField("Nickname", text: $nickname)
                    SecureField("Card number (optional)", text: $number)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button {
                        scanResultHandled = false
                        autoSaveTriggered = false
                        showScanner = true
                    } label: {
                        Label("Scan card with camera", systemImage: "camera.viewfinder")
                    }
                    .disabled(!cameraScanAvailable)
                    if !cameraScanAvailable {
                        Text("Requires an iOS 16 device with a camera. In the simulator, enter details manually.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
    }

    // MARK: - Scanner
    @State private var showScanner = false

    @ViewBuilder
    private var scannerSheet: some View {
        if #available(iOS 16.0, *) {
            NavigationView {
                GeometryReader { proxy in
                    let focusRect = CGRect(x: 0.02, y: 0.26, width: 0.96, height: 0.40)
                    ZStack {
                        CardScannerView(
                            focusAreaNormalized: focusRect,
                            onResult: handleScanResult,
                            onCancel: { showScanner = false }
                        )
                        .ignoresSafeArea()

                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white, lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .frame(width: proxy.size.width * focusRect.width,
                                   height: proxy.size.height * focusRect.height)
                            .position(x: proxy.size.width * (focusRect.minX + focusRect.width / 2),
                                      y: proxy.size.height * (focusRect.minY + focusRect.height / 2))
                            .scaleEffect(framePulse ? 1.02 : 0.98)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: framePulse)
                            .shadow(color: .black.opacity(0.4), radius: 16)
                            .allowsHitTesting(false)

                        VStack {
                            Spacer()
                            HStack {
                                Label("Scanning card...", systemImage: "camera.metering.center.weighted.average")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.black.opacity(0.4), in: Capsule())
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                        }
                        .allowsHitTesting(false)
                    }
                    .onAppear { framePulse = true }
                }
                .navigationTitle("Scan Card")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showScanner = false }
                    }
                }
                .toolbarBackground(.black.opacity(0.4), for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        } else {
            Text("Card scanning requires iOS 16 or later.")
                .padding()
        }
    }

    private var cameraScanAvailable: Bool {
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        }
        return false
    }

    private var canSave: Bool {
        let digits = number.filter(\.isNumber)
        let hasNumber = digits.count >= 4 || digits.isEmpty
        return hasNumber && !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleScanResult(scannedNumber: String, scannedExpiry: String?, scannedName: String?) {
        guard !scanResultHandled else { return }
        scanResultHandled = true
        number = scannedNumber
        // Keep scanner open until user closes; no auto-dismiss
    }

    private func save() {
        let digits = number.filter(\.isNumber)
        let last4 = digits.isEmpty ? "0000" : String(digits.suffix(4))
        let card = CardInfo(
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            fullNumber: digits.isEmpty ? nil : formatFullNumber(digits),
            last4: last4,
            limit: Double(limitText),
            balance: Double(balanceText),
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        onSave(card)
        dismiss()
    }

    private func attemptAutoSave() {
        guard !autoSaveTriggered else { return }
        guard canSave else { return }
        autoSaveTriggered = true
        save()
    }

    private func guessBrand(from number: String) -> String? {
        let digits = number.filter(\.isNumber)
        guard let first = digits.first else { return nil }
        if first == "4" { return "Visa" }
        if digits.hasPrefix("34") || digits.hasPrefix("37") { return "American Express" }
        return nil
    }
}

struct CardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var card: CardInfo
    var onUpdate: (CardInfo) -> Void
    var onDelete: () -> Void

    @State private var nickname: String = ""
    @State private var fullNumber: String = ""
    @State private var limitText: String = ""
    @State private var balanceText: String = ""
    @State private var tagsText: String = ""

    init(card: CardInfo, onUpdate: @escaping (CardInfo) -> Void, onDelete: @escaping () -> Void) {
        self.card = card
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _nickname = State(initialValue: card.nickname)
        _fullNumber = State(initialValue: card.fullNumber ?? card.last4)
        _limitText = State(initialValue: card.limit.map { String($0) } ?? "")
        _balanceText = State(initialValue: card.balance.map { String($0) } ?? "")
        _tagsText = State(initialValue: (card.tags ?? []).joined(separator: ", "))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card details")) {
                    TextField("Nickname", text: $nickname)
                    TextField("Card number (optional)", text: $fullNumber)
                        .keyboardType(.numberPad)
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

                Section(footer: Text("Only the last 4 digits are stored. Full number and CVC are never saved.")) {
                    EmptyView()
                }
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
        let digits = fullNumber.filter(\.isNumber)
        let hasNumber = digits.count >= 4 || digits.isEmpty
        return hasNumber && !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let digits = fullNumber.filter(\.isNumber)
        let trimmedLast4 = digits.isEmpty ? "0000" : String(digits.suffix(4))
        let updated = CardInfo(
            id: card.id,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            fullNumber: digits.isEmpty ? nil : formatFullNumber(digits),
            last4: trimmedLast4,
            limit: Double(limitText),
            balance: Double(balanceText),
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        onUpdate(updated)
        dismiss()
    }
}

