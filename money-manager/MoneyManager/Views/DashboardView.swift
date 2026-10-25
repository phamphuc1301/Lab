import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \TransactionRecord.date, order: .reverse) private var records: [TransactionRecord]
    @Query private var budgets: [Budget]
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrency

    @State private var month = Date()
    @State private var captureAction: CaptureAction?
    @State private var editing: TransactionDraft?

    private let calendar = Calendar.current

    private var monthRecords: [TransactionRecord] {
        let interval = calendar.monthInterval(containing: month)
        return records.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    private var expenses: [TransactionRecord] { monthRecords.filter { $0.kind == .expense } }
    private var income: Decimal { monthRecords.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount } }
    private var spent: Decimal { expenses.reduce(0) { $0 + $1.amount } }

    private var statuses: [BudgetStatus] {
        BudgetAnalyzer.statuses(
            expenses: expenses.map(\.expenseItem),
            budgets: budgets.map(\.budgetLimit),
            month: month
        )
    }

    private var categoryTotals: [(category: TransactionCategory, amount: Decimal)] {
        Dictionary(grouping: expenses, by: \.category)
            .map { (category: $0.key, amount: $0.value.reduce(Decimal(0)) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }

    private var dailyTotals: [(day: Date, amount: Double)] {
        Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, amount: $0.value.reduce(Decimal(0)) { $0 + $1.amount }.doubleValue) }
            .sorted { $0.day < $1.day }
    }

    private var isCurrentMonth: Bool { calendar.isDate(month, equalTo: .now, toGranularity: .month) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthSwitcher
                    summaryCard
                    ForEach(statuses.filter { $0.level != .ok }.sorted { $0.level > $1.level }) { status in
                        BudgetAlertCard(status: status, currencyCode: currencyCode)
                    }
                    if !categoryTotals.isEmpty {
                        categoryCard
                        dailyCard
                    }
                    recentCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { CaptureMenu(action: $captureAction) }
            }
            .transactionCapture(action: $captureAction)
            .sheet(item: $editing) { TransactionEditorView(draft: $0) }
        }
    }

    // MARK: - Sections

    private var monthSwitcher: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .disabled(isCurrentMonth)
                .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 4)
    }

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spent this month").font(.subheadline).foregroundStyle(.secondary)
                Text(spent.currencyString(currencyCode))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                HStack {
                    metric("Income", income.currencyString(currencyCode))
                    Divider().frame(height: 32)
                    metric("Balance", (income - spent).currencyString(currencyCode))
                    if let overall = statuses.first(where: { $0.scopeKey == Budget.overallKey }) {
                        Divider().frame(height: 32)
                        metric("Budget left", overall.remaining.currencyString(currencyCode))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spending by category").font(.headline)
                Chart(categoryTotals, id: \.category) { item in
                    BarMark(
                        x: .value("Amount", item.amount.doubleValue),
                        y: .value("Category", item.category.title)
                    )
                    .foregroundStyle(item.category.color)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(item.amount.currencyString(currencyCode))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                // Leave room on the right for the value labels.
                .chartXScale(domain: 0...((categoryTotals.first?.amount.doubleValue ?? 1) * 1.4))
                .frame(height: CGFloat(categoryTotals.count) * 34 + 10)
            }
        }
    }

    private var dailyCard: some View {
        let overall = budgets.first { $0.scopeKey == Budget.overallKey }
        let days = Double(calendar.range(of: .day, in: .month, for: month)?.count ?? 30)
        let dailyBudget = overall.map { $0.limit.doubleValue / days }

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily spending").font(.headline)
                Chart {
                    ForEach(dailyTotals, id: \.day) { item in
                        BarMark(x: .value("Day", item.day, unit: .day), y: .value("Spent", item.amount))
                            .foregroundStyle(Color.accentColor)
                            .cornerRadius(3)
                    }
                    if let dailyBudget {
                        RuleMark(y: .value("Daily budget", dailyBudget))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .leading) {
                                Text("Daily budget").font(.caption2).foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXScale(domain: calendar.monthInterval(containing: month).start...calendar.monthInterval(containing: month).end)
                .frame(height: 160)
            }
        }
    }

    private var recentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent").font(.headline)
                if monthRecords.isEmpty {
                    Text("No transactions this month. Tap + to scan a receipt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monthRecords.prefix(5)) { record in
                        Button { editing = TransactionDraft(record: record) } label: {
                            TransactionRow(record: record, currencyCode: currencyCode)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shiftMonth(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: month) { month = next }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct BudgetAlertCard: View {
    let status: BudgetStatus
    let currencyCode: String

    private var style: (icon: String, color: Color, label: String) {
        switch status.level {
        case .exceeded: ("exclamationmark.octagon.fill", .red, "Over budget")
        case .warning: ("exclamationmark.triangle.fill", .orange, "Close to limit")
        case .trendingOver: ("chart.line.uptrend.xyaxis", .yellow, "Spending fast")
        case .ok: ("checkmark.circle.fill", .green, "On track")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style.icon)
                .font(.title2)
                .foregroundStyle(style.color)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(style.label): \(status.title)").font(.subheadline.weight(.semibold))
                Text(status.message(currency: currencyCode)).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
