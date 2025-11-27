import SwiftUI
import AVFoundation
import Vision
import CoreImage

@available(iOS 15.0, *)
struct LiveCardScannerView: UIViewControllerRepresentable {
    var focusAreaNormalized: CGRect
    var onResult: (String, String?, String?) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(focusAreaNormalized: focusAreaNormalized, onResult: onResult, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.delegate = context.coordinator
        controller.focusAreaNormalized = focusAreaNormalized
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: ScannerController, coordinator: Coordinator) {
        uiViewController.stopSession()
    }

    final class ScannerController: UIViewController {
        var focusAreaNormalized: CGRect = .zero
        weak var delegate: Coordinator?

        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private let videoOutput = AVCaptureVideoDataOutput()
        private let sessionQueue = DispatchQueue(label: "card-scan-session")

        override func viewDidLoad() {
            super.viewDidLoad()
            setupSession()
        }

        private func setupSession() {
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.delegate?.cancel()
                    return
                }
                self.session.addInput(input)

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                let queue = DispatchQueue(label: "card-scan-video")
                self.videoOutput.setSampleBufferDelegate(self.delegate, queue: queue)
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }

                self.session.commitConfiguration()

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let layer = AVCaptureVideoPreviewLayer(session: self.session)
                    layer.videoGravity = .resizeAspectFill
                    layer.frame = self.view.bounds
                    self.view.layer.addSublayer(layer)
                    self.previewLayer = layer
                }

                self.sessionQueue.async {
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                }
            }
        }

        func stopSession() {
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                if self.session.isRunning {
                    self.session.stopRunning()
                }
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let focusAreaNormalized: CGRect
        private let onResult: (String, String?, String?) -> Void
        private let onCancel: () -> Void
        private var frameCounter = 0
        private var hasEmitted = false
        private var numberVotes: [String: Int] = [:]
        private var expiryCandidate: String?
        private let ciContext = CIContext()
        private let stateQueue = DispatchQueue(label: "card-scan-coordinator-state")

        init(focusAreaNormalized: CGRect, onResult: @escaping (String, String?, String?) -> Void, onCancel: @escaping () -> Void) {
            self.focusAreaNormalized = focusAreaNormalized
            self.onResult = onResult
            self.onCancel = onCancel
        }

        func cancel() {
            onCancel()
        }

        nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            var shouldProcess = true
            stateQueue.sync {
                if hasEmitted { shouldProcess = false; return }
                frameCounter += 1
            }
            if !shouldProcess { return }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let orientation: CGImagePropertyOrientation = .right
            let request = VNRecognizeTextRequest { [weak self] req, _ in
                self?.handle(request: req)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.02
            request.recognitionLanguages = ["en-US"]
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let filtered = ciImage
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 1.45
                ])
                .applyingFilter("CIExposureAdjust", parameters: [
                    kCIInputEVKey: 0.5
                ])

            if let cgImage = ciContext.createCGImage(filtered, from: filtered.extent) {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                try? handler.perform([request])
            } else {
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
                try? handler.perform([request])
            }
        }

        private func handle(request: VNRequest) {
            var alreadyDone = false
            stateQueue.sync { alreadyDone = hasEmitted }
            if alreadyDone { return }

            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let largeObservations = observations.filter { obs in
                return obs.boundingBox.height >= 0.02
            }
            let transcripts = largeObservations.compactMap { $0.topCandidates(1).first?.string.replacingOccurrences(of: "\n", with: " ") }
            guard !transcripts.isEmpty else { return }

            if let expiry = bestExpiry(in: transcripts) {
                stateQueue.async { [weak self] in
                    self?.expiryCandidate = expiry
                }
            }

            if let number = bestCardNumber(in: transcripts) {
                var shouldFinish = false
                var expiry: String?
                var holder: String?
                stateQueue.sync {
                    numberVotes[number, default: 0] += 1
                    let votes = numberVotes[number, default: 0]
                    let digits = number.filter(\.isNumber)
                    let luhnOK = luhnCheck(number)
                    if ((luhnOK && digits.count >= 15) || votes >= 3) && !hasEmitted {
                        hasEmitted = true
                        shouldFinish = true
                        expiry = expiryCandidate
                    }
                }
                if shouldFinish {
                    holder = bestName(in: transcripts)
                    finish(number: number, expiry: expiry, holder: holder)
                }
            }
        }

        private func finish(number: String, expiry: String?, holder: String?) {
            var didSet = false
            stateQueue.sync {
                if !hasEmitted { hasEmitted = true; didSet = true }
            }
            guard didSet else { return }
            DispatchQueue.main.async {
                self.onResult(number, expiry, holder)
            }
        }

        private func bestCardNumber(in transcripts: [String]) -> String? {
            let combined = transcripts.joined(separator: " ")
            if let grouped = firstMatch(in: combined, pattern: "(\\d{4}[\\s-]\\d{4}[\\s-]\\d{4}[\\s-]\\d{3,4})") {
                let digits = grouped.filter(\.isNumber)
                if (13...19).contains(digits.count) { return format(number: digits) }
            }
            if let match = firstMatch(in: combined, pattern: "(\\d[\\d\\s]{13,24}\\d)") {
                let digits = match.filter(\.isNumber)
                if (12...19).contains(digits.count) { return format(number: digits) }
            }
            for text in transcripts {
                let digits = text.filter(\.isNumber)
                if (13...19).contains(digits.count) { return format(number: digits) }
            }
            return nil
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

        private func luhnCheck(_ formatted: String) -> Bool {
            let digits = formatted.filter(\.isNumber).compactMap { Int(String($0)) }
            guard digits.count >= 13 else { return false }
            var sum = 0
            for (idx, digit) in digits.reversed().enumerated() {
                if idx % 2 == 1 {
                    let doubled = digit * 2
                    sum += doubled > 9 ? doubled - 9 : doubled
                } else {
                    sum += digit
                }
            }
            return sum % 10 == 0
        }
    }
}

