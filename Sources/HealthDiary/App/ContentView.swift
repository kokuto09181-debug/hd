import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MealPlannerView()
                .tabItem { Label("献立", systemImage: "fork.knife") }

            ShoppingListView()
                .tabItem { Label("買い出し", systemImage: "cart.fill") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
    }
}
