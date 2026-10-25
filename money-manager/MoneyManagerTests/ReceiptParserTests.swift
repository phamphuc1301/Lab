import CoreGraphics
import XCTest
@testable import MoneyManager

final class ReceiptParserTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func parser(dayFirst: Bool = true) -> ReceiptParser {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        return ReceiptParser(prefersDayFirst: dayFirst, now: now, calendar: calendar)
    }

    private func decimal(_ string: String) -> Decimal { Decimal(string: string)! }

    func testParseAmountFormats() {
        XCTAssertEqual(ReceiptParser.parseAmount("1,234.56"), decimal("1234.56"))
        XCTAssertEqual(ReceiptParser.parseAmount("1.234,56"), decimal("1234.56"))
        XCTAssertEqual(ReceiptParser.parseAmount("125.000"), decimal("125000"))
        XCTAssertEqual(ReceiptParser.parseAmount("125,000"), decimal("125000"))
        XCTAssertEqual(ReceiptParser.parseAmount("1.250.000đ"), decimal("1250000"))
        XCTAssertEqual(ReceiptParser.parseAmount("12.50"), decimal("12.5"))
        XCTAssertEqual(ReceiptParser.parseAmount("12,5"), decimal("12.5"))
        XCTAssertEqual(ReceiptParser.parseAmount("$5.72"), decimal("5.72"))
        XCTAssertEqual(ReceiptParser.parseAmount("45000 VND"), decimal("45000"))
        XCTAssertNil(ReceiptParser.parseAmount("abc"))
    }

    func testEnglishReceipt() {
        let rows = [
            "STARBUCKS COFFEE",
            "123 Main St",
            "Date: 03/14/2026 10:22",
            "Latte 5.25",
            "Subtotal 5.25",
            "Tax 0.47",
            "TOTAL 5.72",
            "Cash 10.00",
            "Change 4.28",
        ]
        let receipt = parser(dayFirst: false).parse(rows: rows)

        XCTAssertEqual(receipt.total, decimal("5.72"))
        XCTAssertEqual(receipt.merchant, "STARBUCKS COFFEE")
        XCTAssertEqual(receipt.category, .food)
        let date = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: receipt.date!)
        XCTAssertEqual(date, DateComponents(year: 2026, month: 3, day: 14, hour: 10, minute: 22))
    }

    func testVietnameseReceipt() {
        let rows = [
            "Highlands Coffee",
            "HÓA ĐƠN THANH TOÁN",
            "Ngày: 25/10/2026 08:15",
            "Phin Sữa Đá x2 58.000",
            "Tổng tiền hàng 58.000",
            "Giảm giá 5.000",
            "Tổng cộng 53.000đ",
            "Tiền khách đưa 100.000",
            "Tiền thừa 47.000",
        ]
        let receipt = parser().parse(rows: rows)

        XCTAssertEqual(receipt.total, decimal("53000"))
        XCTAssertEqual(receipt.merchant, "Highlands Coffee")
        XCTAssertEqual(receipt.category, .food)
        let date = calendar.dateComponents([.year, .month, .day], from: receipt.date!)
        XCTAssertEqual(date, DateComponents(year: 2026, month: 10, day: 25))
    }

    func testTotalOnFollowingLine() {
        let rows = ["WinMart", "Grand Total", "1.250.000", "Thank you"]
        let receipt = parser().parse(rows: rows)
        XCTAssertEqual(receipt.total, decimal("1250000"))
        XCTAssertEqual(receipt.category, .groceries)
    }

    func testFallsBackToLargestAmountWithoutTotalLabel() {
        let rows = ["Corner Shop", "Tel: 0901234567", "Bread 2.50", "Milk 3.10", "9.80"]
        XCTAssertEqual(parser().parse(rows: rows).total, decimal("9.80"))
    }

    func testRejectsInvalidAndFutureDates() {
        XCTAssertNil(parser().date(in: ["31/02/2026"]))
        XCTAssertNil(parser().date(in: ["01/12/2026"]))
        XCTAssertNotNil(parser().date(in: ["2026-10-05"]))
    }

    func testGroupsObservationsIntoRows() {
        let lines = [
            OCRLine(text: "53.000", box: CGRect(x: 0.7, y: 0.40, width: 0.2, height: 0.04)),
            OCRLine(text: "Highlands Coffee", box: CGRect(x: 0.2, y: 0.90, width: 0.6, height: 0.05)),
            OCRLine(text: "Tổng cộng", box: CGRect(x: 0.1, y: 0.41, width: 0.3, height: 0.04)),
        ]
        XCTAssertEqual(ReceiptParser.rows(from: lines), ["Highlands Coffee", "Tổng cộng 53.000"])
    }
}
