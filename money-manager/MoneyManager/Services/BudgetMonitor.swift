import Foundation
import SwiftData
import UserNotifications

/// Re-checks budgets after data changes and posts a local notification
/// the first time a budget reaches "warning" or "exceeded" in a month.
@MainActor
enum BudgetMonitor {
    static func requestAuthorization() async {
        guard AppSettings.alertsEnabled else { return }
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func check(context: ModelContext, month: Date, calendar: Calendar = .current) {
        guard AppSettings.alertsEnabled,
              let interval = calendar.dateInterval(of: .month, for: month) else { return }

        let start = interval.start
        let end = interval.end
        let expense = TransactionKind.expense.rawValue
        let descriptor = FetchDescriptor<TransactionRecord>(
            predicate: #Predicate { $0.date >= start && $0.date < end && $0.kindRaw == expense }
        )
        guard let records = try? context.fetch(descriptor),
              let budgets = try? context.fetch(FetchDescriptor<Budget>()) else { return }

        let statuses = BudgetAnalyzer.statuses(
            expenses: records.map(\.expenseItem),
            budgets: budgets.map(\.budgetLimit),
            month: month,
            calendar: calendar
        )
        notify(statuses, month: month, calendar: calendar)
    }

    private static func notify(_ statuses: [BudgetStatus], month: Date, calendar: Calendar) {
        let defaults = UserDefaults.standard
        let monthKey = calendar.dateComponents([.year, .month], from: month)
        let currency = AppSettings.currencyCode

        for status in statuses where status.level >= .warning {
            let key = "budgetAlert-\(monthKey.year ?? 0)-\(monthKey.month ?? 0)-\(status.scopeKey)"
            // Only notify when the level escalates, so each alert fires once per month.
            guard defaults.integer(forKey: key) < status.level.rawValue else { continue }
            defaults.set(status.level.rawValue, forKey: key)

            let content = UNMutableNotificationContent()
            content.title = status.level == .exceeded
                ? "Budget exceeded: \(status.title)"
                : "Budget warning: \(status.title)"
            content.body = status.message(currency: currency)
            content.sound = .default

            let request = UNNotificationRequest(identifier: key, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
