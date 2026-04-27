import SwiftUI
import SwiftData

@main
struct HealthDiaryApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    @State private var showOnboarding = false

    // ModelContainer をここで生成することで、スキーマ変更時の
    // マイグレーション失敗をキャッチして旧ストアを削除できる
    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !onboardingCompleted {
                        showOnboarding = true
                    }
                    Task {
                        await LLMService.shared.autoDownloadIfNeeded()
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
        }
        .modelContainer(container)
    }

    // MARK: - Container Factory

    private static let allModels: [any PersistentModel.Type] = [
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
        PantryItem.self,
        IngredientAlias.self,
    ]

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(allModels)

        // 1回目: 通常起動を試みる
        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // マイグレーション失敗 — 旧ストアをすべて削除して再作成
        // (開発中はデータ損失を許容する。将来はマイグレーションプランで対応)
        purgeStores()
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("SwiftData: ストア再作成にも失敗しました: \(error)")
        }
    }

    /// SwiftData のストアファイルをすべて削除する
    private static func purgeStores() {
        let fm = FileManager.default
        let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeExtensions = ["sqlite", "sqlite-wal", "sqlite-shm"]

        // SwiftData はデフォルトで "default.store" というファイル名を使う
        for ext in storeExtensions {
            let url = supportDir.appendingPathComponent("default.store").appendingPathExtension(ext)
            try? fm.removeItem(at: url)
        }

        // フォルダ内の .sqlite 系ファイルも念のため掃除
        if let contents = try? fm.contentsOfDirectory(at: supportDir, includingPropertiesForKeys: nil) {
            for file in contents where storeExtensions.contains(file.pathExtension) {
                try? fm.removeItem(at: file)
            }
        }
    }
}
