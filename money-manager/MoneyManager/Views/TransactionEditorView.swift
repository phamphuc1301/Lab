import SwiftData
import SwiftUI

/// Editable copy of a transaction, used for new, scanned and existing transactions.
struct TransactionDraft: Identifiable {
    let id = UUID()
    var existing: TransactionRecord?
    var amount: Decimal = 0
    var kind: TransactionKind = .expense
    var category: TransactionCategory = .food
    var merchant = ""
    var note = ""
    var date = Date()
    var receiptImage: Data?
    var scanNotice: String?

    init() {}

    init(record: TransactionRecord) {
        existing = record
        amount = record.amount
        kind = record.kind
        category = record.category
        merchant = record.merchant
        note = record.note
        date = record.date
        receiptImage = record.receiptImage
    }

    init(receipt: ParsedReceipt, imageData: Data?) {
        amount = receipt.total ?? 0
        category = receipt.category
        merchant = receipt.merchant ?? ""
        date = receipt.date ?? .now
        receiptImage = imageData
        scanNotice = receipt.total == nil
            ? "The total couldn't be found. Please enter the amount."
            : "Filled in from the receipt. Check the values before saving."
    }
}

struct TransactionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrency

    @State private var draft: TransactionDraft
    @State private var amountText: String
    @State private var showReceipt = false
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    init(draft: TransactionDraft) {
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: draft.amount.editableString)
    }

    private var parsedAmount: Decimal? {
        ReceiptParser.parseAmount(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let notice = draft.scanNotice {
                    Section {
                        Label(notice, systemImage: "doc.text.viewfinder")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker("Type", selection: $draft.kind) {
                        ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title.bold())
                            .focused($amountFocused)
                        Text(currencyCode).foregroundStyle(.secondary)
                    }
                }

                Section("Details") {
                    Picker("Category", selection: $draft.category) {
                        ForEach(TransactionCategory.all(for: draft.kind)) { category in
                            Label(category.title, systemImage: category.symbol).tag(category)
                        }
                    }
                    TextField(draft.kind == .expense ? "Merchant" : "Payer", text: $draft.merchant)
                    DatePicker("Date", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note", text: $draft.note, axis: .vertical)
                }

                if let data = draft.receiptImage, let image = UIImage(data: data) {
                    Section("Receipt") {
                        Button { showReceipt = true } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .frame(maxWidth: .infinity)
                        }
                        Button("Remove image", role: .destructive) { draft.receiptImage = nil }
                    }
                    .sheet(isPresented: $showReceipt) { ReceiptImageView(image: image) }
                }

                if draft.existing != nil {
                    Section {
                        Button("Delete transaction", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(draft.existing == nil ? "New transaction" : "Edit transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(parsedAmount == nil)
                }
            }
            .onChange(of: draft.kind) { _, kind in
                if draft.category.isIncome != (kind == .income) {
                    draft.category = TransactionCategory.all(for: kind)[0]
                }
            }
            .onAppear { if draft.amount == 0 { amountFocused = true } }
            .confirmationDialog("Delete this transaction?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            }
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let record = draft.existing ?? TransactionRecord()
        record.amount = amount
        record.kind = draft.kind
        record.category = draft.category
        record.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        record.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        record.date = draft.date
        record.receiptImage = draft.receiptImage
        if draft.existing == nil { context.insert(record) }
        try? context.save()

        if record.kind == .expense {
            BudgetMonitor.check(context: context, month: record.date)
        }
        dismiss()
    }

    private func delete() {
        if let record = draft.existing {
            context.delete(record)
            try? context.save()
        }
        dismiss()
    }
}

private struct ReceiptImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: 800)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
