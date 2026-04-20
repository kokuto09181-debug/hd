import SwiftUI
import SwiftData

@main
struct HealthDiaryApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !onboardingCompleted {
                        showOnboarding = true
                    }
                    // バックグラウンドで LLM モデルを自動ダウンロード
                    Task {
                        await LLMService.shared.autoDownloadIfNeeded()
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
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
