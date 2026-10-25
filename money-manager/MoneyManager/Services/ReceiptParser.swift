import CoreGraphics
import Foundation

struct ParsedReceipt {
    var total: Decimal?
    var date: Date?
    var merchant: String?
    var category: TransactionCategory
    var rows: [String]
}

/// Turns OCR output into a best-guess total, date, merchant and category.
/// Handles both "1,234.56" and Vietnamese-style "125.000đ" amounts.
struct ReceiptParser {
    var prefersDayFirst: Bool = ReceiptParser.localePrefersDayFirst
    var now: Date = .now
    var calendar: Calendar = .current

    func parse(lines: [OCRLine]) -> ParsedReceipt {
        parse(rows: Self.rows(from: lines))
    }

    func parse(rows: [String]) -> ParsedReceipt {
        let merchant = Self.merchant(in: rows)
        return ParsedReceipt(
            total: Self.total(in: rows),
            date: date(in: rows),
            merchant: merchant,
            category: Self.category(merchant: merchant, rows: rows),
            rows: rows
        )
    }

    // MARK: - Rows

    /// Vision often returns the label and the price of a receipt line as separate
    /// observations. Group observations that sit on the same baseline into one row.
    static func rows(from lines: [OCRLine]) -> [String] {
        let topToBottom = lines.sorted { $0.box.midY > $1.box.midY }
        var rows: [[OCRLine]] = []
        for line in topToBottom {
            if let anchor = rows.last?.first,
               abs(anchor.box.midY - line.box.midY) < max(anchor.box.height, line.box.height) * 0.5 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
    }

    // MARK: - Total

    private static let strongTotalKeywords = [
        "grand total", "amount due", "balance due", "total due", "total amount", "net total",
        "tong cong", "tong thanh toan", "khach phai tra", "phai thanh toan", "thanh toan",
    ]
    private static let totalKeywords = ["total", "tong tien", "tong", "thanh tien", "amount", "sum"]
    private static let excludedKeywords = [
        "subtotal", "sub total", "sub-total", "tax", "vat", "cash", "change", "tendered", "discount",
        "tip", "tien hang", "tien mat", "khach dua", "tien thua", "tra lai", "giam gia", "chiet khau", "thue",
    ]

    static func total(in rows: [String]) -> Decimal? {
        var best: (weight: Int, amount: Decimal)?

        for (index, row) in rows.enumerated() {
            let folded = fold(row)
            guard !excludedKeywords.contains(where: folded.contains) else { continue }

            let weight: Int
            if strongTotalKeywords.contains(where: folded.contains) {
                weight = 2
            } else if totalKeywords.contains(where: folded.contains) {
                weight = 1
            } else {
                continue
            }

            var amount = amounts(in: row).max()
            // Some layouts put the value on the line below the label.
            if amount == nil, index + 1 < rows.count, isAmountOnly(rows[index + 1]) {
                amount = amounts(in: rows[index + 1]).max()
            }
            guard let amount else { continue }

            if best == nil || weight > best!.weight || (weight == best!.weight && amount > best!.amount) {
                best = (weight, amount)
            }
        }

        if let best { return best.amount }

        // No labelled total: fall back to the largest amount that isn't cash/change/tax.
        return rows
            .filter { row in !excludedKeywords.contains(where: fold(row).contains) }
            .flatMap(amounts(in:))
            .max()
    }

    private static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(?:\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?!\d)"#
    )
    private static let dateLikeRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}(?!\d)"#
    )
    private static let timeRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)\d{1,2}:\d{2}(?::\d{2})?(?!\d)"#
    )

    static func amounts(in text: String) -> [Decimal] {
        var cleaned = text
        for regex in [dateLikeRegex, timeRegex] {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: " "
            )
        }
        return amountRegex
            .matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned))
            .compactMap { Range($0.range, in: cleaned).map { String(cleaned[$0]) } }
            // Long bare digit runs are phone numbers, tax IDs or invoice numbers, not prices.
            .filter { token in token.contains(where: { $0 == "." || $0 == "," }) || token.count <= 7 }
            .compactMap(parseAmount)
            .filter { $0 > 0 }
    }

    private static func isAmountOnly(_ row: String) -> Bool {
        let letters = row.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        return letters <= 3 && !amounts(in: row).isEmpty
    }

    /// Parses "1,234.56", "1.234,56", "125.000", "125,000", "12.50" or "45000đ".
    /// A lone separator followed by exactly three digits is treated as a thousands separator.
    static func parseAmount(_ raw: String) -> Decimal? {
        let kept = raw.filter { ($0.isASCII && $0.isNumber) || $0 == "." || $0 == "," }
        let s = kept.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        guard s.contains(where: { $0.isASCII && $0.isNumber }) else { return nil }

        let decimalSeparator: Character?
        switch (s.lastIndex(of: "."), s.lastIndex(of: ",")) {
        case let (dot?, comma?):
            decimalSeparator = dot > comma ? "." : ","
        case (.some, nil):
            decimalSeparator = isDecimalSeparator(".", in: s) ? "." : nil
        case (nil, .some):
            decimalSeparator = isDecimalSeparator(",", in: s) ? "," : nil
        case (nil, nil):
            decimalSeparator = nil
        }

        let decimalIndex = decimalSeparator.flatMap { s.lastIndex(of: $0) }
        var normalized = ""
        for index in s.indices {
            if index == decimalIndex {
                normalized.append(".")
            } else if s[index].isASCII && s[index].isNumber {
                normalized.append(s[index])
            }
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func isDecimalSeparator(_ separator: Character, in s: String) -> Bool {
        let parts = s.split(separator: separator, omittingEmptySubsequences: false)
        return parts.count == 2 && parts[1].count != 3
    }

    // MARK: - Date

    private static let ymdRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)"#
    )
    private static let dmyRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})(?!\d)"#
    )
    private static let hourMinuteRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#
    )

    func date(in rows: [String]) -> Date? {
        for row in rows {
            guard var components = dateComponents(in: row) else { continue }
            if let time = Self.firstMatch(Self.hourMinuteRegex, in: row),
               let hour = Int(time[0]), let minute = Int(time[1]), hour < 24, minute < 60 {
                components.hour = hour
                components.minute = minute
            }
            if let date = validDate(from: components) { return date }
        }
        return nil
    }

    private func dateComponents(in row: String) -> DateComponents? {
        if let m = Self.firstMatch(Self.ymdRegex, in: row),
           let year = Int(m[0]), let month = Int(m[1]), let day = Int(m[2]) {
            return DateComponents(year: year, month: month, day: day)
        }
        if let m = Self.firstMatch(Self.dmyRegex, in: row),
           let first = Int(m[0]), let second = Int(m[1]), var year = Int(m[2]) {
            if year < 100 { year += 2000 }
            let dayFirst = first > 12 || (second <= 12 && prefersDayFirst)
            return DateComponents(year: year, month: dayFirst ? second : first, day: dayFirst ? first : second)
        }
        return nil
    }

    private func validDate(from components: DateComponents) -> Date? {
        guard let year = components.year, year >= 2000,
              let date = calendar.date(from: components) else { return nil }
        // Reject rollovers such as 31/02 becoming 3 March.
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == components.year, check.month == components.month, check.day == components.day,
              date <= now.addingTimeInterval(86_400) else { return nil }
        return date
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> [String]? {
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
    }

    static var localePrefersDayFirst: Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "dMy", options: 0, locale: .current) ?? "d/M/y"
        guard let d = format.firstIndex(of: "d"), let m = format.firstIndex(of: "M") else { return true }
        return d < m
    }

    // MARK: - Merchant & category

    private static let headerNoise = [
        "receipt", "invoice", "hoa don", "phieu", "bill", "welcome", "tel:", "tel.", "sdt", "phone", "dien thoai",
        "address", "dia chi", "mst", "tax id", "www", "http", "cashier", "thu ngan", "order", "date", "ngay",
    ]

    static func merchant(in rows: [String]) -> String? {
        for row in rows.prefix(6) {
            let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
            let folded = fold(trimmed)
            guard !headerNoise.contains(where: folded.contains) else { continue }

            let visible = trimmed.unicodeScalars.filter { !CharacterSet.whitespaces.contains($0) }
            let letters = visible.filter { CharacterSet.letters.contains($0) }
            guard letters.count >= 3, Double(letters.count) / Double(visible.count) >= 0.6 else { continue }
            return String(trimmed.prefix(40))
        }
        return nil
    }

    private static let categoryKeywords: [(TransactionCategory, [String])] = [
        (.food, ["coffee", "cafe", "ca phe", "tra sua", "milk tea", "restaurant", "nha hang", "pizza", "burger",
                 "kfc", "mcdonald", "lotteria", "jollibee", "highlands", "starbucks", "phuc long", "bakery",
                 "bistro", "kitchen", "grill", "noodle", "food", "quan an", "bun bo", "pho "]),
        (.groceries, ["supermarket", "sieu thi", "grocery", "winmart", "bach hoa", "coop", "co.op", "aeon",
                      "lotte mart", "mega market", "7-eleven", "circle k", "familymart", "ministop",
                      "walmart", "costco", "tesco", "mart"]),
        (.transport, ["grab", "gojek", "taxi", "xang", "petrol", "fuel", "gas station", "parking",
                      "gui xe", "uber", "petrolimex", "be group", "vetc"]),
        (.health, ["pharmacy", "nha thuoc", "hospital", "benh vien", "clinic", "phong kham",
                   "pharmacity", "long chau", "an khang"]),
        (.bills, ["electric", "dien luc", "evn", "internet", "viettel", "vnpt", "mobifone", "vinaphone",
                  "utility", "cap nuoc"]),
        (.entertainment, ["cinema", "cgv", "galaxy", "bhd", "netflix", "spotify", "karaoke", "ticket"]),
        (.travel, ["hotel", "khach san", "airline", "vietjet", "vietnam airlines", "bamboo", "agoda", "booking"]),
        (.shopping, ["shopee", "lazada", "tiki", "uniqlo", "zara", "fashion", "store", "shop"]),
    ]

    static func category(merchant: String?, rows: [String]) -> TransactionCategory {
        let sources = [merchant.map(fold) ?? "", fold(rows.joined(separator: " "))]
        for source in sources where !source.isEmpty {
            if let match = categoryKeywords.first(where: { $0.1.contains(where: source.contains) }) {
                return match.0
            }
        }
        return .other
    }

    /// Lowercase, strip diacritics ("Tổng cộng" -> "tong cong", "Đ" -> "d").
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "đ", with: "d")
    }
}
