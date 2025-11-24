import Foundation
import CoreMotion

struct Transaction: Identifiable, Codable, Equatable {
    enum Kind: String, CaseIterable, Codable { case income, expense }

    var id: UUID = UUID()
    var amount: Double
    var category: String
    var date: Date
    var kind: Kind
}

struct CardInfo: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var nickname: String
    var brand: String
    var holder: String
    var fullNumber: String?
    var last4: String
    var expiry: String
    var limit: Double?
    var balance: Double?
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
