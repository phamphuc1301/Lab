import SwiftData
import SwiftUI

struct BudgetsView: View {
    @Environment(\.modelContext) private var context
    @Query private var budgets: [Budget]
    @Query private var records: [TransactionRecord]
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrency

    @State private var editing: BudgetDraft?

    private var statuses: [BudgetStatus] {
        BudgetAnalyzer.statuses(
            expenses: records.filter { $0.kind == .expense }.map(\.expenseItem),
            budgets: budgets.map(\.budgetLimit),
            month: .now
        )
    }

    private var usedScopes: Set<String> { Set(budgets.map(\.scopeKey)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(statuses) { status in
                        Button { edit(status.scopeKey) } label: {
                            BudgetRow(status: status, currencyCode: currencyCode)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let keys = offsets.map { statuses[$0].scopeKey }
                        for budget in budgets where keys.contains(budget.scopeKey) { context.delete(budget) }
                        try? context.save()
                    }
                } footer: {
                    Text("Budgets reset every month. You'll get a notification when spending passes the warning level or the limit.")
                }
            }
            .overlay {
                if budgets.isEmpty {
                    ContentUnavailableView {
                        Label("No budgets", systemImage: "target")
                    } description: {
                        Text("Set a monthly limit for all spending or for a category.")
                    } actions: {
                        Button("Add budget") { editing = BudgetDraft(usedScopes: usedScopes) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { editing = BudgetDraft(usedScopes: usedScopes) } label: {
                        Label("Add budget", systemImage: "plus")
                    }
                    .disabled(usedScopes.count > TransactionCategory.all(for: .expense).count)
                }
            }
            .sheet(item: $editing) { BudgetEditorView(draft: $0) }
        }
    }

    private func edit(_ scopeKey: String) {
        guard let budget = budgets.first(where: { $0.scopeKey == scopeKey }) else { return }
        editing = BudgetDraft(budget: budget, usedScopes: usedScopes)
    }
}

private struct BudgetRow: View {
    let status: BudgetStatus
    let currencyCode: String

    private var tint: Color {
        switch status.level {
        case .exceeded: .red
        case .warning: .orange
        case .trendingOver: .yellow
        case .ok: .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let category = status.category {
                    CategoryIcon(category: category)
                } else {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 9))
                }
                VStack(alignment: .leading) {
                    Text(status.title).font(.body.weight(.medium))
                    Text("\(status.spent.currencyString(currencyCode)) of \(status.limit.currencyString(currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int((status.ratio * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: min(status.ratio, 1))
                .tint(tint)
            if status.level != .ok {
                Label(status.message(currency: currencyCode), systemImage: status.level == .exceeded
                      ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct BudgetDraft: Identifiable {
    let id = UUID()
    var existing: Budget?
    var scopeKey: String
    var limit: Decimal = 0
    var warnThreshold: Double = 0.8
    /// Scopes the picker may offer (unused ones, plus this budget's own).
    let availableScopes: [String]

    init(usedScopes: Set<String>) {
        let all = [Budget.overallKey] + TransactionCategory.all(for: .expense).map(\.rawValue)
        availableScopes = all.filter { !usedScopes.contains($0) }
        scopeKey = availableScopes.first ?? Budget.overallKey
    }

    init(budget: Budget, usedScopes: Set<String>) {
        let all = [Budget.overallKey] + TransactionCategory.all(for: .expense).map(\.rawValue)
        availableScopes = all.filter { !usedScopes.contains($0) || $0 == budget.scopeKey }
        existing = budget
        scopeKey = budget.scopeKey
        limit = budget.limit
        warnThreshold = budget.warnThreshold
    }
}

private struct BudgetEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrency

    @State private var draft: BudgetDraft
    @State private var limitText: String

    init(draft: BudgetDraft) {
        _draft = State(initialValue: draft)
        _limitText = State(initialValue: draft.limit.editableString)
    }

    private var parsedLimit: Decimal? {
        ReceiptParser.parseAmount(limitText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Applies to", selection: $draft.scopeKey) {
                    ForEach(draft.availableScopes, id: \.self) { Text(Budget.title(for: $0)).tag($0) }
                }
                Section("Monthly limit") {
                    HStack {
                        TextField("0", text: $limitText)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                        Text(currencyCode).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Slider(value: $draft.warnThreshold, in: 0.5...0.95, step: 0.05)
                } header: {
                    Text("Warn me at \(Int((draft.warnThreshold * 100).rounded()))% of the limit")
                }
            }
            .navigationTitle(draft.existing == nil ? "New budget" : "Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(parsedLimit == nil)
                }
            }
        }
    }

    private func save() {
        guard let limit = parsedLimit else { return }
        if let budget = draft.existing {
            budget.scopeKey = draft.scopeKey
            budget.limit = limit
            budget.warnThreshold = draft.warnThreshold
        } else {
            context.insert(Budget(scopeKey: draft.scopeKey, limit: limit, warnThreshold: draft.warnThreshold))
        }
        try? context.save()
        BudgetMonitor.check(context: context, month: .now)
        dismiss()
    }
}
