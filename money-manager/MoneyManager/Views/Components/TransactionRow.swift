import SwiftUI

struct TransactionRow: View {
    let record: TransactionRecord
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: record.category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(record.displayTitle).font(.body.weight(.medium)).lineLimit(1)
                    if record.receiptImage != nil {
                        Image(systemName: "paperclip").font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel("Has receipt")
                    }
                }
                Text(record.note.isEmpty ? record.category.title : record.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text((record.kind == .income ? record.amount : -record.amount).currencyString(currencyCode))
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(record.kind == .income ? Color.green : Color.primary)
        }
        .contentShape(Rectangle())
    }
}

struct CategoryIcon: View {
    let category: TransactionCategory

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(category.color.gradient, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }
}
