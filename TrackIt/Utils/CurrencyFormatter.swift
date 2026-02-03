import Foundation

struct CurrencyFormatter {

    static func format(_ amount: Double) -> String {
        amount.formatted(.currency(code: AppConstants.Currency.code))
    }

    static func formatWithSuffix(_ amount: Double, suffix: String) -> String {
        "\(format(amount))\(suffix)"
    }

    static func formatPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

// MARK: - Double Extension

extension Double {
    func formattedAsCurrency() -> String {
        CurrencyFormatter.format(self)
    }

    func formattedAsCurrency(suffix: String) -> String {
        CurrencyFormatter.formatWithSuffix(self, suffix: suffix)
    }

    func formattedAsPercentage() -> String {
        CurrencyFormatter.formatPercentage(self)
    }

    func percentageChange(from previous: Double) -> Double? {
        let minDivisor = 0.01
        guard abs(previous) > minDivisor else { return nil }
        return ((self - previous) / abs(previous)) * 100
    }
}
