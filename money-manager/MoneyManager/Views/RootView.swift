import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "chart.bar.xaxis") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
            BudgetsView()
                .tabItem { Label("Budgets", systemImage: "target") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task { await BudgetMonitor.requestAuthorization() }
    }
}
