import Foundation

enum SettingsKey {
    static let currencyCode = "currencyCode"
    static let alertsEnabled = "budgetAlertsEnabled"
}

enum AppSettings {
    static var defaultCurrency: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: SettingsKey.currencyCode) ?? defaultCurrency
    }

    static var alertsEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.alertsEnabled) as? Bool ?? true
    }

    static let commonCurrencies = ["VND", "USD", "EUR", "GBP", "JPY", "KRW", "CNY", "SGD", "THB", "AUD", "CAD"]
}
