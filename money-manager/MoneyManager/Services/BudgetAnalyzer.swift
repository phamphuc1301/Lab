import Foundation

struct ExpenseItem {
    let category: TransactionCategory
    let amount: Decimal
    let date: Date
}

struct BudgetLimit {
    let scopeKey: String
    let limit: Decimal
    let warnThreshold: Double
}

enum BudgetLevel: Int, Comparable {
    case ok
    /// Under the warning threshold, but the current pace ends the month over the limit.
    case trendingOver
    case warning
    case exceeded

    static func < (lhs: BudgetLevel, rhs: BudgetLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct BudgetStatus: Identifiable {
    let scopeKey: String
    let limit: Decimal
    let spent: Decimal
    /// Spending extrapolated to the end of the month at the current daily pace.
    let projected: Decimal
    let warnThreshold: Double
    /// Days left in the month including today; nil when the month is not the current one.
    let daysLeft: Int?

    var id: String { scopeKey }
    var title: String { Budget.title(for: scopeKey) }
    var category: TransactionCategory? { TransactionCategory(rawValue: scopeKey) }

    var ratio: Double {
        limit > 0 ? (spent / limit).doubleValue : 0
    }

    var remaining: Decimal { limit - spent }

    /// How much can still be spent per day to stay within the limit.
    var dailyAllowance: Decimal? {
        guard let daysLeft, daysLeft > 0, remaining > 0 else { return nil }
        return remaining / Decimal(daysLeft)
    }

    var level: BudgetLevel {
        if spent >= limit { return .exceeded }
        if ratio >= warnThreshold { return .warning }
        if projected > limit { return .trendingOver }
        return .ok
    }

    func message(currency: String) -> String {
        switch level {
        case .exceeded:
            return "Over budget by \((spent - limit).currencyString(currency)). Spent \(spent.currencyString(currency)) of \(limit.currencyString(currency))."
        case .warning:
            var text = "\(Int((ratio * 100).rounded()))% used, \(remaining.currencyString(currency)) left."
            if let allowance = dailyAllowance {
                text += " About \(allowance.currencyString(currency))/day for the rest of the month."
            }
            return text
        case .trendingOver:
            return "At this pace you'll spend about \(projected.currencyString(currency)) this month, \((projected - limit).currencyString(currency)) over the limit."
        case .ok:
            return "\(remaining.currencyString(currency)) left of \(limit.currencyString(currency))."
        }
    }
}

enum BudgetAnalyzer {
    /// Days into the month before the pace-based projection is trusted.
    static let minimumDaysForProjection = 5

    static func statuses(
        expenses: [ExpenseItem],
        budgets: [BudgetLimit],
        month: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [BudgetStatus] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }

        let inMonth = expenses.filter { $0.date >= interval.start && $0.date < interval.end }
        let total = inMonth.reduce(Decimal(0)) { $0 + $1.amount }
        let byCategory = Dictionary(grouping: inMonth, by: \.category)
            .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }

        let isCurrentMonth = now >= interval.start && now < interval.end
        let daysInMonth = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        let paceFactor: Decimal = isCurrentMonth && dayOfMonth >= minimumDaysForProjection
            ? Decimal(daysInMonth) / Decimal(dayOfMonth)
            : 1
        let daysLeft = isCurrentMonth ? daysInMonth - dayOfMonth + 1 : nil

        return budgets
            .filter { $0.limit > 0 }
            .map { budget in
                let spent: Decimal
                if budget.scopeKey == Budget.overallKey {
                    spent = total
                } else if let category = TransactionCategory(rawValue: budget.scopeKey) {
                    spent = byCategory[category] ?? 0
                } else {
                    spent = 0
                }
                return BudgetStatus(
                    scopeKey: budget.scopeKey,
                    limit: budget.limit,
                    spent: spent,
                    projected: spent * paceFactor,
                    warnThreshold: budget.warnThreshold,
                    daysLeft: daysLeft
                )
            }
            .sorted { lhs, rhs in
                if lhs.scopeKey == Budget.overallKey { return rhs.scopeKey != Budget.overallKey }
                if rhs.scopeKey == Budget.overallKey { return false }
                return lhs.title < rhs.title
            }
    }
}
