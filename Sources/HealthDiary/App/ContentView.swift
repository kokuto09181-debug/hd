import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MealPlannerView()
                .tabItem {
                    Label("献立", systemImage: "fork.knife")
                }

            ShoppingListView()
                .tabItem {
                    Label("買い出し", systemImage: "cart")
                }

            FoodLogView()
                .tabItem {
                    Label("食事記録", systemImage: "camera")
                }

            ActivityLogView()
                .tabItem {
                    Label("運動", systemImage: "figure.run")
                }

            ChatView()
                .tabItem {
                    Label("相談", systemImage: "bubble.left")
                }
        }
    }
}
