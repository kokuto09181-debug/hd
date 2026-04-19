import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            MealPlannerView()
                .tabItem {
                    Label("献立", systemImage: "fork.knife")
                }

            FoodLogView()
                .tabItem {
                    Label("記録", systemImage: "camera")
                }

            FamilyProfileView()
                .tabItem {
                    Label("家族", systemImage: "person.2.fill")
                }
        }
    }
}
