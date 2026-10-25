import UIKit
import Vision

/// One line of recognized text. `box` is Vision's normalized rect (origin bottom-left).
struct OCRLine: Equatable {
    let text: String
    let box: CGRect
}

enum ReceiptScanError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: "The image couldn't be read."
        case .noTextFound: "No text was found. Try a clearer, well-lit photo of the receipt."
        }
    }
}

/// On-device OCR using Apple's Vision framework. No network or API key needed.
enum ReceiptTextRecognizer {
    static func recognize(_ image: UIImage) async throws -> [OCRLine] {
        guard let cgImage = image.cgImage else { throw ReceiptScanError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        let lines = try await Task.detached(priority: .userInitiated) { () -> [OCRLine] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            if let supported = try? request.supportedRecognitionLanguages() {
                let preferred = ["vi-VT", "en-US"].filter(supported.contains)
                if !preferred.isEmpty { request.recognitionLanguages = preferred }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            return (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first.map {
                    OCRLine(text: $0.string, box: observation.boundingBox)
                }
            }
        }.value

        if lines.isEmpty { throw ReceiptScanError.noTextFound }
        return lines
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
