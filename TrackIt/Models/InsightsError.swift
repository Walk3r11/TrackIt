import Foundation

enum InsightsError: LocalizedError {
    case calculationFailed(Error)

    case invalidData

    case insufficientData

    case dateCalculationFailed

    case cancelled

    var errorDescription: String? {
        switch self {
        case .calculationFailed(let error):
            return "Failed to calculate insights: \(error.localizedDescription)"
        case .invalidData:
            return "Transaction data is invalid"
        case .insufficientData:
            return "Not enough data to generate insights"
        case .dateCalculationFailed:
            return "Failed to calculate date range"
        case .cancelled:
            return "Calculation was cancelled"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .calculationFailed:
            return "Try refreshing the data or restarting the app."
        case .invalidData:
            return "Check your transaction entries for any errors."
        case .insufficientData:
            return "Add more transactions to see insights."
        case .dateCalculationFailed:
            return "Try selecting a different time period."
        case .cancelled:
            return "The operation was interrupted. Please try again."
        }
    }
}
