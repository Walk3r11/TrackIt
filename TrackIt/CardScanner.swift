import SwiftUI
import VisionKit

@available(iOS 16.0, *)
struct CardScannerView: UIViewControllerRepresentable {
    var focusAreaNormalized: CGRect
    var onResult: (String, String?, String?) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let recognizedTypes: Set<DataScannerViewController.RecognizedDataType> = [.text()]

        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        DispatchQueue.main.async {
            try? scanner.startScanning()
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        weak var scanner: DataScannerViewController?
        private let onResult: (String, String?, String?) -> Void
        private let onCancel: () -> Void
        private var hasEmitted = false

        init(onResult: @escaping (String, String?, String?) -> Void, onCancel: @escaping () -> Void) {
            self.onResult = onResult
            self.onCancel = onCancel
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            process(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            process(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            process(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            process([item])
        }

        func dataScannerDidCancel(_ dataScanner: DataScannerViewController) {
            onCancel()
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didFailWithError error: Error) {
            onCancel()
        }

        private func process(_ items: [RecognizedItem]) {
            guard !hasEmitted else { return }

            let transcripts: [String] = items.compactMap {
                if case let .text(text) = $0 {
                    return text.transcript.replacingOccurrences(of: "\n", with: " ")
                }
                return nil
            }

            let cardNumber = bestCardNumber(in: transcripts)
            let expiry = bestExpiry(in: transcripts)
            let holder = bestName(in: transcripts)
            let cvc = bestCVC(in: transcripts, excludingNumber: cardNumber)

            if let cardNumber {
                finish(number: cardNumber, expiry: expiry, holder: holder, cvc: cvc)
            }
        }

        private func bestCardNumber(in transcripts: [String]) -> String? {
            let combined = transcripts.joined(separator: " ")
            var candidates: [String] = []

            if let grouped = firstMatch(in: combined, pattern: "(\\d{4}[\\s-]\\d{4}[\\s-]\\d{4}[\\s-]\\d{3,4})") {
                let digits = grouped.filter(\.isNumber)
                if (15...19).contains(digits.count) { candidates.append(digits) }
            }

            let digitChunks = transcripts
                .flatMap { $0.split(whereSeparator: { !$0.isNumber }).map(String.init) }
                .filter { (3...6).contains($0.count) }
            let totalDigits = digitChunks.reduce(0) { $0 + $1.count }
            if digitChunks.count >= 3, totalDigits >= 12 {
                let joined = digitChunks.prefix(4).joined()
                if (12...19).contains(joined.count) {
                    candidates.append(joined)
                }
            }

            if let match = firstMatch(in: combined, pattern: "(\\d[\\d\\s]{13,24}\\d)") {
                let digits = match.filter(\.isNumber)
                if (12...19).contains(digits.count) { candidates.append(digits) }
            }

            for text in transcripts {
                let digits = text.filter(\.isNumber)
                guard (12...19).contains(digits.count) else { continue }
                candidates.append(digits)
            }

            guard let chosen = candidates.sorted(by: { lhs, rhs in
                let target = 16
                let scoreL = abs(target - lhs.count)
                let scoreR = abs(target - rhs.count)
                if scoreL == scoreR { return lhs.count > rhs.count }
                return scoreL < scoreR
            }).first else { return nil }

            return format(number: chosen)
        }

        private func bestExpiry(in transcripts: [String]) -> String? {
            let pattern = "(0[1-9]|1[0-2])[\\s/\\-]?(\\d{2})"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let currentYY = Calendar.current.component(.year, from: .now) % 100
            for text in transcripts {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let monthRange = Range(match.range(at: 1), in: text),
                   let yearRange = Range(match.range(at: 2), in: text) {
                    let yyString = text[yearRange]
                    if let yy = Int(yyString),
                       yy >= currentYY,
                       yy <= currentYY + 15 {
                        return "\(text[monthRange])/\(yyString)"
                    }
                }
            }
            return nil
        }

        private func bestCVC(in transcripts: [String], excludingNumber number: String?) -> String? {
            let numberDigits = number?.filter(\.isNumber) ?? ""
            let combined = transcripts.joined(separator: " ")

            let cvcKeywords = ["CVC", "CVV", "CVN"]
            for keyword in cvcKeywords {
                if let match = firstMatch(in: combined, pattern: "\(keyword)\\s*[:]?\\s*(\\d{3,4})") {
                    return match.filter(\.isNumber)
                }
            }

            var candidates: [String] = []
            for text in transcripts {
                let parts = text.split(separator: " ").map(String.init)
                for part in parts {
                    let digits = part.filter(\.isNumber)
                    guard digits.count == 3 || digits.count == 4 else { continue }
                    if !numberDigits.contains(digits) {
                        candidates.append(digits)
                    }
                }
            }

            return candidates.first
        }

        private func bestName(in transcripts: [String]) -> String? {
            let blockers = ["BANK", "CARD", "DEBIT", "CREDIT", "VALID", "THRU", "GOOD", "MONTH", "YEAR", "VISA", "MASTERCARD", "PLATINUM", "CLASSIC", "VIRTUAL", "DSK", "VIRI", "GOLD", "WORLD", "BUSINESS"]
            var best: String?
            for text in transcripts {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { continue }
                let upper = cleaned.uppercased()
                if upper.rangeOfCharacter(from: .decimalDigits) != nil { continue }
                if upper.rangeOfCharacter(from: CharacterSet.letters.inverted.subtracting(.whitespaces)) != nil { continue }
                if blockers.contains(where: { upper.contains($0) }) { continue }
                let words = upper.split(separator: " ")
                guard words.count >= 2, words.count <= 4 else { continue }
                let hasVowel = upper.rangeOfCharacter(from: CharacterSet(charactersIn: "AEIOU")) != nil
                guard hasVowel else { continue }
                let wordValidity = words.allSatisfy { $0.count >= 2 && $0.rangeOfCharacter(from: CharacterSet(charactersIn: "AEIOU")) != nil }
                guard wordValidity else { continue }
                let candidate = words.joined(separator: " ")
                guard candidate.count >= 6, candidate.count <= 24 else { continue }
                if best == nil || candidate.count > best!.count { best = candidate }
            }
            return best
        }

        private func firstMatch(in text: String, pattern: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
            guard let matchRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[matchRange])
        }

        private func format(number: String) -> String {
            stride(from: 0, to: number.count, by: 4).map { idx in
                let start = number.index(number.startIndex, offsetBy: idx)
                let end = number.index(start, offsetBy: 4, limitedBy: number.endIndex) ?? number.endIndex
                return String(number[start..<end])
            }.joined(separator: " ")
        }

        private func finish(number: String, expiry: String?, holder: String?, cvc: String?) {
            guard !hasEmitted else { return }
            hasEmitted = true
            onResult(number, expiry, holder)
            scanner?.stopScanning()
        }
    }
}
