import SwiftUI

struct ContentView: View {
    @StateObject private var store = StoreService.shared

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }

            MealPlannerView()
                .tabItem { Label("献立", systemImage: "fork.knife") }

            FoodLogView()
                .tabItem { Label("記録", systemImage: "camera") }

            FamilyProfileView()
                .tabItem { Label("家族", systemImage: "person.2.fill") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !store.isPremium {
                AdBannerPlaceholder()
            }
        }
    }
}

// MARK: - Ad Banner

private struct AdBannerPlaceholder: View {
    var body: some View {
        HStack {
            Spacer()
            Text("広告スペース")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(height: 50)
        .background(Color(.systemGray6))
        .overlay(alignment: .top) { Divider() }
    }
}
