import Foundation
import SwiftUI

enum AppConstants: Sendable {

    // MARK: - Currency

    enum Currency: Sendable {
        static let code = "EUR"

        static let locale = Locale.current
    }

    // MARK: - Layout

    enum Layout: Sendable {
        static let maxContentWidth: CGFloat = 540

        static let horizontalPadding: CGFloat = 16

        static let cardCornerRadius: CGFloat = 18

        static let selectorCornerRadius: CGFloat = 20

        static let cardSpacing: CGFloat = 14

        static let sectionSpacing: CGFloat = 18
    }

    // MARK: - Animation

    enum Animation: Sendable {
        static let defaultDuration: Double = 0.3

        static let springResponse: Double = 0.4

        static let springDamping: Double = 0.85

        static let debounceNanoseconds: UInt64 = 300_000_000

        static let sectionLoadDelay: UInt64 = 50_000_000
    }

    // MARK: - Insights

    enum Insights: Sendable {
        static let maxCategoriesInChart: Int = 7

        static let maxMonthsInComparison: Int = 6

        static let maxLargestTransactions: Int = 6

        static let recommendedSavingsRate: Double = 20.0

        static let minDivisor: Double = 0.01
    }

    // MARK: - Time

    enum Time: Sendable {
        static let secondsInDay: TimeInterval = 86400

        static let maxTransactionGap: TimeInterval = 86400 * 30
    }

    // MARK: - Refresh

    enum Refresh: Sendable {
        static let fullRefreshNanoseconds: UInt64 = 30_000_000_000
        static let ticketMessagesNanoseconds: UInt64 = 10_000_000_000
    }
}
