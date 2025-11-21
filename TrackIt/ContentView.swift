//
//  ContentView.swift
//  TrackIt
//
//  Created by Konstantin Nikolow on 5.11.25.
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Models
struct Transaction: Identifiable {
    enum Kind: String, CaseIterable { case income, expense }

    let id = UUID()
    var amount: Double
    var category: String
    var date: Date
    var kind: Kind
}

// MARK: - Motion Manager
@MainActor
final class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    private var basePitch: Double?
    private var baseRoll: Double?

    init() {
        #if targetEnvironment(simulator)
        #else
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1 / 60
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data = data else { return }
                let currentPitch = data.attitude.pitch
                let currentRoll = data.attitude.roll
                if self.basePitch == nil { self.basePitch = currentPitch }
                if self.baseRoll == nil { self.baseRoll = currentRoll }
                self.pitch = currentPitch - (self.basePitch ?? 0)
                self.roll = currentRoll - (self.baseRoll ?? 0)
            }
        }
        #endif
    }

    deinit {
        #if !targetEnvironment(simulator)
        motion.stopDeviceMotionUpdates()
        #endif
    }
}

// MARK: - Period Enum
enum Period: String, CaseIterable {
    case daily, weekly, biweekly, monthly, quarterly, semiannual, nineMonth, yearly
    var title: String {
        switch self {
        case .daily: "Today"
        case .weekly: "Past 7 Days"
        case .biweekly: "Past 14 Days"
        case .monthly: "Past Month"
        case .quarterly: "Past 3 Months"
        case .semiannual: "Past 6 Months"
        case .nineMonth: "Past 9 Months"
        case .yearly: "Past Year"
        }
    }
}

// MARK: - Palette
private enum Palette {
    static let backgroundTop = Color(red: 0.99, green: 0.96, blue: 0.92)
    static let backgroundMid = Color(red: 0.95, green: 0.93, blue: 0.97)
    static let backgroundBottom = Color(red: 0.90, green: 0.93, blue: 0.98)
    static let card = Color.white.opacity(0.92)
    static let stroke = Color.black.opacity(0.06)
    static let primary = Color(red: 0.1, green: 0.11, blue: 0.2)
    static let secondary = Color.black.opacity(0.55)
    static let accent = Color(red: 0.98, green: 0.56, blue: 0.27)
    static let accentAlt = Color(red: 0.16, green: 0.55, blue: 0.67)
    static let mutedFill = Color.black.opacity(0.03)
}

// MARK: - Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var selectedPeriod: Period = .daily
    @State private var shimmerOffset: CGFloat = -300
    @StateObject private var motion = MotionManager()
    @State private var showAddSheet = false
    @State private var transactions: [Transaction] = []

    var body: some View {
        let income = totalIncome
        let expenses = totalExpenses
        let net = netBalance
        let breakdown = categoryBreakdown
        let filtered = filteredTransactions

        TabView(selection: $selectedTab) {
            dashboard
                .tag(0)
                .tabItem { Label("Home", systemImage: "house.fill") }

            PlaceholderTab(title: "Cards")
                .tag(1)
                .tabItem { Label("Cards", systemImage: "creditcard.fill") }

            PlaceholderTab(title: "AI")
                .tag(2)
                .tabItem { Label("AI", systemImage: "brain.head.profile") }

            PlaceholderTab(title: "Settings")
                .tag(3)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .preferredColorScheme(.light)
    }

    private var dashboard: some View {
        let income = totalIncome
        let expenses = totalExpenses
        let net = netBalance
        let breakdown = categoryBreakdown
        let filtered = filteredTransactions

        return HomeDashboard(
            selectedPeriod: $selectedPeriod,
            shimmerOffset: $shimmerOffset,
            motion: motion,
            transactions: $transactions,
            showAddSheet: $showAddSheet,
            netBalance: net,
            totalIncome: income,
            totalExpenses: expenses,
            categoryBreakdown: breakdown,
            filteredTransactions: filtered,
            onAdd: { showAddSheet = true }
        )
    }

    private var periodStart: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .daily:
            return calendar.startOfDay(for: .now)
        case .weekly:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        case .biweekly:
            return calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: .now)) ?? .now
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
        case .quarterly:
            return calendar.date(byAdding: .month, value: -3, to: .now) ?? .now
        case .semiannual:
            return calendar.date(byAdding: .month, value: -6, to: .now) ?? .now
        case .nineMonth:
            return calendar.date(byAdding: .month, value: -9, to: .now) ?? .now
        case .yearly:
            return calendar.date(byAdding: .year, value: -1, to: .now) ?? .now
        }
    }

    private var filteredTransactions: [Transaction] {
        transactions.filter { $0.date >= periodStart }
    }

    private var totalIncome: Double {
        filteredTransactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        filteredTransactions
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double {
        totalIncome - totalExpenses
    }

    private var categoryBreakdown: [String: Double] {
        filteredTransactions
            .filter { $0.kind == .expense }
            .reduce(into: [:]) { partialResult, transaction in
                partialResult[transaction.category, default: 0] += transaction.amount
            }
    }
}

// MARK: - Tabs
struct HomeDashboard: View {
    @Binding var selectedPeriod: Period
    @Binding var shimmerOffset: CGFloat
    @ObservedObject var motion: MotionManager
    @Binding var transactions: [Transaction]
    @Binding var showAddSheet: Bool
    var netBalance: Double
    var totalIncome: Double
    var totalExpenses: Double
    var categoryBreakdown: [String: Double]
    var filteredTransactions: [Transaction]
    var onAdd: () -> Void

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    FinanceHeader(
                        netBalance: netBalance,
                        income: totalIncome,
                        expenses: totalExpenses,
                        shimmerOffset: shimmerOffset,
                        motion: motion,
                        onAdd: onAdd
                    )

                    PeriodPicker(selectedPeriod: $selectedPeriod)

                    HStack(spacing: 14) {
                        MetricCard(title: "Income", amount: totalIncome, icon: "arrow.down.right.circle.fill", tint: Palette.accentAlt)
                        MetricCard(title: "Expenses", amount: totalExpenses, icon: "arrow.up.right.circle.fill", tint: Palette.accent)
                    }

                    SnapshotCard(
                        title: "Spending Overview",
                        subtitle: selectedPeriod.title,
                        income: totalIncome,
                        expenses: totalExpenses,
                        breakdown: categoryBreakdown
                    )

                    TransactionsCard(transactions: filteredTransactions, onAdd: onAdd)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 12)
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionSheet { newTransaction in
                transactions.insert(newTransaction, at: 0)
            }
        }
    }
}

struct PlaceholderTab: View {
    var title: String
    var body: some View {
        ZStack {
            AnimatedBackground()
            Text("\(title) coming soon")
                .foregroundColor(Palette.primary.opacity(0.8))
                .font(.headline)
                .padding()
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.stroke, lineWidth: 1))
        }
    }
}

// MARK: - Animated Background
struct AnimatedBackground: View {
    @State private var move = false
    @State private var hueShift: Angle = .degrees(0)

    var body: some View {
        LinearGradient(
            colors: [
                Palette.backgroundTop,
                Palette.backgroundMid,
                Palette.backgroundBottom
            ],
            startPoint: move ? .topLeading : .bottomTrailing,
            endPoint: move ? .bottomTrailing : .topLeading
        )
        .animation(.easeInOut(duration: 30).repeatForever(autoreverses: true), value: move)
        .overlay {
            RadialGradient(
                gradient: Gradient(colors: [
                    Palette.accent.opacity(0.25),
                    Palette.accentAlt.opacity(0.18),
                    .clear
                ]),
                center: move ? .bottomLeading : .topTrailing,
                startRadius: 50,
                endRadius: 700
            )
            .blur(radius: 240)
            .animation(.easeInOut(duration: 18).repeatForever(autoreverses: true), value: move)
        }
        .hueRotation(hueShift)
        .onAppear {
            move.toggle()
            withAnimation(.linear(duration: 80).repeatForever(autoreverses: true)) {
                hueShift = .degrees(8)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Header / Hero
struct FinanceHeader: View {
    var netBalance: Double
    var income: Double
    var expenses: Double
    var shimmerOffset: CGFloat
    @ObservedObject var motion: MotionManager
    var onAdd: () -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Palette.accent,
                            Palette.accentAlt
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Palette.stroke, lineWidth: 1.2)
                )
                .shadow(color: Palette.accent.opacity(0.35), radius: 18, x: 0, y: 12)
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.25), .white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(RoundedRectangle(cornerRadius: 26))
                    .offset(x: shimmerOffset)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: false), value: shimmerOffset)
                )
                .rotation3DEffect(.degrees(motion.pitch * 6), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(motion.roll * -6), axis: (x: 0, y: 1, z: 0))

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TrackIt")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Daily finance pulse")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    Button(action: onAdd) {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Net Balance")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text(netBalance, format: .currency(code: currencyCode))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(income >= expenses ? "Cash flow positive" : "Cash flow negative")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(income >= expenses ? .white.opacity(0.85) : .white.opacity(0.85))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.white.opacity(0.14), in: Capsule())
                }

                HStack(spacing: 12) {
                    PillMetric(title: "Income", value: income, icon: "arrow.down.forward", tint: Palette.accentAlt)
                    PillMetric(title: "Expenses", value: expenses, icon: "arrow.up.forward", tint: Palette.card)
                }
            }
            .padding(22)
        }
    }
}

// MARK: - Metric Cards
struct MetricCard: View {
    var title: String
    var amount: Double
    var icon: String
    var tint: Color
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                Spacer()
                Text(amount, format: .currency(code: currencyCode))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Palette.primary)
            }
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundColor(Palette.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Palette.card,
                    Palette.card.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Palette.mutedFill, radius: 8, x: 0, y: 8)
    }
}

// MARK: - Period Picker
struct PeriodPicker: View {
    @Binding var selectedPeriod: Period

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Period.allCases, id: \.self) { period in
                    PeriodPill(period: period, isSelected: period == selectedPeriod) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedPeriod = period
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }
}
private struct PeriodPill: View {
    var period: Period
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Text(period.title)
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(isSelected ? Palette.accent.opacity(0.18) : Palette.mutedFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Palette.accent : Palette.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .foregroundColor(Palette.primary)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .onTapGesture(perform: onTap)
    }
}

// MARK: - Spending Snapshot
struct SnapshotCard: View {
    var title: String
    var subtitle: String
    var income: Double
    var expenses: Double
    var breakdown: [String: Double]
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Palette.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                }
                Spacer()
                Text("Net \(income - expenses, format: .currency(code: currencyCode))")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor((income - expenses) >= 0 ? Palette.accentAlt : Palette.accent)
            }

            ProgressRow(
                title: "Income",
                value: income,
                maxValue: max(income, expenses, 1),
                tint: Palette.accentAlt
            )
            ProgressRow(
                title: "Expenses",
                value: expenses,
                maxValue: max(income, expenses, 1),
                tint: Palette.accent
            )

            Divider().background(Color.white.opacity(0.08))

            if breakdown.isEmpty {
                Text("No expenses recorded for this period yet.")
                    .font(.callout)
                    .foregroundColor(Palette.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(breakdown.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                        HStack {
                            Text(category)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Palette.primary)
                            Spacer()
                            Text(amount, format: .currency(code: currencyCode))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(Palette.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }
}

// MARK: - Recent Transactions
struct TransactionsCard: View {
    var transactions: [Transaction]
    var onAdd: () -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundColor(Palette.primary)
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(Palette.accentAlt)
            }

            if transactions.isEmpty {
                EmptyStateView(
                    title: "No transactions yet",
                    message: "Tap Add to log your first expense or income."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions.prefix(6)) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.category)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Palette.primary)
                                Text(dateFormatter.string(from: transaction.date))
                                    .font(.caption)
                                    .foregroundColor(Palette.secondary)
                            }
                            Spacer()
                            Text(transaction.amount, format: .currency(code: currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(transaction.kind == .income ? Palette.accentAlt : Palette.accent)
                        }
                        .padding(.vertical, 12)

                        if transaction.id != transactions.prefix(6).last?.id {
                            Divider().background(Palette.stroke)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke, lineWidth: 1))
    }
}

struct EmptyStateView: View {
    var title: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Palette.primary)
            Text(message)
                .font(.footnote)
                .foregroundColor(Palette.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.mutedFill, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Pills
struct PillMetric: View {
    var title: String
    var value: Double
    var icon: String
    var tint: Color
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white.opacity(0.85))
                Text(value, format: .currency(code: currencyCode))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Progress Row
struct ProgressRow: View {
    var title: String
    var value: Double
    var maxValue: Double
    var tint: Color
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundColor(Palette.primary)
                Spacer()
                Text(value, format: .currency(code: currencyCode))
                    .foregroundColor(Palette.secondary)
                    .font(.footnote.weight(.medium))
            }
            GeometryReader { proxy in
                let ratio = maxValue == 0 ? 0 : value / maxValue
                RoundedRectangle(cornerRadius: 10)
                    .fill(Palette.mutedFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(tint.gradient)
                            .frame(width: proxy.size.width * CGFloat(min(ratio, 1)))
                            .animation(.easeInOut(duration: 0.4), value: value)
                    }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Add Transaction Sheet
struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Transaction) -> Void
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
                    TextField("Category", text: $category)
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
        guard let amount = Double(amountText) else { return }
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = Transaction(amount: amount, category: trimmedCategory, date: date, kind: kind)
        onSave(transaction)
        dismiss()
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
