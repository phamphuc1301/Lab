import SwiftUI

enum TransactionKind: String, CaseIterable, Identifiable, Codable {
    case expense
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        }
    }
}

enum TransactionCategory: String, CaseIterable, Identifiable, Codable {
    // Expense categories
    case food, groceries, transport, shopping, bills, housing, health, entertainment, education, travel, other
    // Income categories
    case salary, bonus, investment, otherIncome

    var id: String { rawValue }

    var isIncome: Bool {
        switch self {
        case .salary, .bonus, .investment, .otherIncome: true
        default: false
        }
    }

    var title: String {
        switch self {
        case .food: "Food & Drink"
        case .groceries: "Groceries"
        case .transport: "Transport"
        case .shopping: "Shopping"
        case .bills: "Bills & Utilities"
        case .housing: "Housing"
        case .health: "Health"
        case .entertainment: "Entertainment"
        case .education: "Education"
        case .travel: "Travel"
        case .other: "Other"
        case .salary: "Salary"
        case .bonus: "Bonus"
        case .investment: "Investment"
        case .otherIncome: "Other income"
        }
    }

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .groceries: "cart"
        case .transport: "car"
        case .shopping: "bag"
        case .bills: "bolt"
        case .housing: "house"
        case .health: "cross.case"
        case .entertainment: "film"
        case .education: "book"
        case .travel: "airplane"
        case .other: "square.grid.2x2"
        case .salary: "banknote"
        case .bonus: "gift"
        case .investment: "chart.line.uptrend.xyaxis"
        case .otherIncome: "plus.circle"
        }
    }

    /// Fixed per-category color so a category keeps its color on every screen.
    var color: Color {
        switch self {
        case .food: .orange
        case .groceries: .green
        case .transport: .blue
        case .shopping: .pink
        case .bills: .yellow
        case .housing: .brown
        case .health: .red
        case .entertainment: .purple
        case .education: .indigo
        case .travel: .cyan
        case .other: .gray
        case .salary, .bonus, .investment, .otherIncome: .mint
        }
    }

    static func all(for kind: TransactionKind) -> [TransactionCategory] {
        allCases.filter { $0.isIncome == (kind == .income) }
    }
}
