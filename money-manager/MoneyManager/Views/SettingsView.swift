import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query(sort: \TransactionRecord.date, order: .reverse) private var records: [TransactionRecord]
    @AppStorage(SettingsKey.currencyCode) private var currencyCode = AppSettings.defaultCurrency
    @AppStorage(SettingsKey.alertsEnabled) private var alertsEnabled = true

    private var currencies: [String] {
        AppSettings.commonCurrencies.contains(currencyCode)
            ? AppSettings.commonCurrencies
            : [currencyCode] + AppSettings.commonCurrencies
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Currency") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.self) { code in
                            Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
                        }
                    }
                }

                Section {
                    Toggle("Budget alerts", isOn: $alertsEnabled)
                        .onChange(of: alertsEnabled) { _, enabled in
                            if enabled { Task { await BudgetMonitor.requestAuthorization() } }
                        }
                } footer: {
                    Text("Sends a notification when a budget reaches its warning level or limit. Warnings are always shown on the Overview tab.")
                }

                Section {
                    ShareLink(
                        item: CSVExport(records: records),
                        preview: SharePreview("Transactions (\(records.count))")
                    ) {
                        Label("Export transactions (CSV)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(records.isEmpty)
                } header: {
                    Text("Data")
                } footer: {
                    Text("All data, including receipt images, is stored only on this device.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
