import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionRecord.date, order: .reverse) private var records: [TransactionRecord]
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrency

    @State private var searchText = ""
    @State private var kindFilter: TransactionKind?
    @State private var captureAction: CaptureAction?
    @State private var editing: TransactionDraft?

    private var filtered: [TransactionRecord] {
        records.filter { record in
            (kindFilter == nil || record.kind == kindFilter)
                && (searchText.isEmpty
                    || record.merchant.localizedCaseInsensitiveContains(searchText)
                    || record.note.localizedCaseInsensitiveContains(searchText)
                    || record.category.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var groupedByDay: [(day: Date, records: [TransactionRecord])] {
        let calendar = Calendar.current
        return Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, records: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay, id: \.day) { group in
                    Section {
                        ForEach(group.records) { record in
                            Button { editing = TransactionDraft(record: record) } label: {
                                TransactionRow(record: record, currencyCode: currencyCode)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for offset in offsets { context.delete(group.records[offset]) }
                            try? context.save()
                        }
                    } header: {
                        Text(group.day.formatted(date: .complete, time: .omitted))
                    }
                }
            }
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No transactions yet",
                        systemImage: "doc.text.viewfinder",
                        description: Text("Tap + to scan a receipt or add a transaction.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Merchant, note or category")
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Show", selection: $kindFilter) {
                            Text("All").tag(TransactionKind?.none)
                            ForEach(TransactionKind.allCases) { Text($0.title).tag(TransactionKind?.some($0)) }
                        }
                    } label: {
                        Label("Filter", systemImage: kindFilter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) { CaptureMenu(action: $captureAction) }
            }
            .transactionCapture(action: $captureAction)
            .sheet(item: $editing) { TransactionEditorView(draft: $0) }
        }
    }
}
