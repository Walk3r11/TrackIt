import SwiftUI

struct AllTransactionsSheet: View {
    var transactions: [Transaction]
    var onAdd: () -> Void
    private let currencyCode = Locale.current.currency?.identifier ?? "USD"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        NavigationView {
            List {
                ForEach(transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transaction.category)
                                .font(.headline)
                            Text(dateFormatter.string(from: transaction.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(transaction.kind == .income ? "+" : "-")\(abs(transaction.amount), format: .currency(code: currencyCode))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(transaction.kind == .income ? Palette.accentAlt : Palette.accent)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("All Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onAdd()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
    }
}
