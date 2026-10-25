import Foundation
import UIKit

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }

    func currencyString(_ code: String) -> String {
        formatted(.currency(code: code).precision(.fractionLength(0...2)))
    }

    /// Plain number for editing, e.g. "125000" or "12.5" (locale decimal separator).
    var editableString: String {
        self == 0 ? "" : formatted(.number.grouping(.never))
    }
}

extension Calendar {
    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}

extension UIImage {
    /// Shrinks large camera photos before storing them with a transaction.
    func compressedJPEG(maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return jpegData(compressionQuality: quality) }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
