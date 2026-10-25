import XCTest
@testable import MoneyManager

final class BudgetAnalyzerTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ day: Int, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func status(
        _ scope: String,
        expenses: [ExpenseItem],
        limit: Decimal,
        now: Date
    ) -> BudgetStatus {
        BudgetAnalyzer.statuses(
            expenses: expenses,
            budgets: [BudgetLimit(scopeKey: scope, limit: limit, warnThreshold: 0.8)],
            month: day(1),
            now: now,
            calendar: calendar
        )[0]
    }

    func testCountsOnlyTheMonthAndCategory() {
        let expenses = [
            ExpenseItem(category: .food, amount: 40, date: day(3)),
            ExpenseItem(category: .food, amount: 45, date: day(20)),
            ExpenseItem(category: .transport, amount: 30, date: day(5)),
            ExpenseItem(category: .food, amount: 500, date: day(2, month: 10)),
        ]
        let food = status(TransactionCategory.food.rawValue, expenses: expenses, limit: 100, now: day(2, month: 10))
        XCTAssertEqual(food.spent, 85)
        XCTAssertEqual(food.level, .warning)

        let overall = status(Budget.overallKey, expenses: expenses, limit: 100, now: day(2, month: 10))
        XCTAssertEqual(overall.spent, 115)
        XCTAssertEqual(overall.level, .exceeded)
    }

    func testProjectsPaceWithinCurrentMonth() {
        // 50 spent by day 10 of a 30-day month -> on pace for 150.
        let expenses = [ExpenseItem(category: .shopping, amount: 50, date: day(4))]
        let result = status(Budget.overallKey, expenses: expenses, limit: 100, now: day(10))

        XCTAssertEqual(result.projected, 150)
        XCTAssertEqual(result.level, .trendingOver)
        XCTAssertEqual(result.daysLeft, 21)
        XCTAssertEqual(result.dailyAllowance!.doubleValue, 50.0 / 21.0, accuracy: 0.0001)
    }

    func testNoProjectionEarlyInMonth() {
        let expenses = [ExpenseItem(category: .shopping, amount: 20, date: day(1))]
        let result = status(Budget.overallKey, expenses: expenses, limit: 100, now: day(2))
        XCTAssertEqual(result.projected, 20)
        XCTAssertEqual(result.level, .ok)
    }
}
