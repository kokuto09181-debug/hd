import SwiftUI
import SwiftData

@main
struct HealthDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            FamilyProfile.self,
            FamilyMember.self,
            MealPlan.self,
            DayPlan.self,
            PlannedMeal.self,
            MealHistoryEntry.self,
            ShoppingList.self,
            ShoppingItem.self,
            FoodLogEntry.self,
            ActivityGoal.self,
            ManualWorkout.self,
            ChatThread.self,
            ChatMessage.self,
        ])
    }
}
