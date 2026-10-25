import Foundation
import SwiftData

@Model
final class TransactionRecord {
    var id: UUID = UUID()
    var amount: Decimal = 0
    // Enums are stored as raw strings so they work in #Predicate queries.
    var kindRaw: String = "expense"
    var categoryRaw: String = "other"
    var merchant: String = ""
    var note: String = ""
    var date: Date = Date()
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var receiptImage: Data?

    init(
        amount: Decimal = 0,
        kind: TransactionKind = .expense,
        category: TransactionCategory = .other,
        merchant: String = "",
        note: String = "",
        date: Date = .now,
        receiptImage: Data? = nil
    ) {
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.categoryRaw = category.rawValue
        self.merchant = merchant
        self.note = note
        self.date = date
        self.receiptImage = receiptImage
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var displayTitle: String {
        merchant.isEmpty ? category.title : merchant
    }

    var expenseItem: ExpenseItem {
        ExpenseItem(category: category, amount: amount, date: date)
    }
}
