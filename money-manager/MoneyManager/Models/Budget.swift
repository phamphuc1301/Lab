import Foundation
import SwiftData

/// A monthly spending limit, either for all expenses ("overall") or for one category.
@Model
final class Budget {
    static let overallKey = "overall"

    /// `Budget.overallKey` or a `TransactionCategory` raw value.
    var scopeKey: String = "overall"
    var limit: Decimal = 0
    /// Fraction of the limit (0...1) at which a warning is raised.
    var warnThreshold: Double = 0.8

    init(scopeKey: String, limit: Decimal, warnThreshold: Double = 0.8) {
        self.scopeKey = scopeKey
        self.limit = limit
        self.warnThreshold = warnThreshold
    }

    var budgetLimit: BudgetLimit {
        BudgetLimit(scopeKey: scopeKey, limit: limit, warnThreshold: warnThreshold)
    }

    static func title(for scopeKey: String) -> String {
        if scopeKey == overallKey { return "All spending" }
        return TransactionCategory(rawValue: scopeKey)?.title ?? scopeKey
    }
}
