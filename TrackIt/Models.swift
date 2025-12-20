import Foundation
import CoreMotion

struct Transaction: Identifiable, Codable, Equatable {
    enum Kind: String, CaseIterable, Codable { case income, expense }

    var id: UUID = UUID()
    var cardId: UUID?
    var amount: Double
    var category: String
    var date: Date
    var kind: Kind
}

struct CardInfo: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var nickname: String
    var limit: Double?
    var limitPeriod: SpendingLimitPeriod? = nil
    var dailyLimit: Double? = nil
    var weeklyLimit: Double? = nil
    var monthlyLimit: Double? = nil
    var balance: Double?
    var tags: [String]?
}

enum SpendingLimitPeriod: String, CaseIterable, Codable {
    case daily
    case weekly
    case monthly

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }
}

extension CardInfo {
    private var hasMultiLimits: Bool {
        dailyLimit != nil || weeklyLimit != nil || monthlyLimit != nil
    }

    func effectiveLimit(for period: SpendingLimitPeriod) -> Double? {
        if hasMultiLimits {
            switch period {
            case .daily: return dailyLimit
            case .weekly: return weeklyLimit
            case .monthly: return monthlyLimit
            }
        }

        guard let limit, limit > 0 else { return nil }
        let legacyPeriod = limitPeriod ?? .daily
        return legacyPeriod == period ? limit : nil
    }

    func effectiveLimitsInDisplayOrder() -> [(period: SpendingLimitPeriod, limit: Double)] {
        let order: [SpendingLimitPeriod] = [.daily, .weekly, .monthly]
        return order.compactMap { period in
            guard let limit = effectiveLimit(for: period), limit > 0 else { return nil }
            return (period, limit)
        }
    }

    func primaryLimitForDisplay() -> (period: SpendingLimitPeriod, limit: Double)? {
        effectiveLimitsInDisplayOrder().first
    }

    func legacyLimitForAPI() -> (limit: Double?, period: SpendingLimitPeriod?) {
        guard let primary = primaryLimitForDisplay() else { return (nil, nil) }
        return (primary.limit, primary.period)
    }
}

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
