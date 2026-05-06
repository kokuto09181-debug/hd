import SwiftUI
import SwiftData

@main
struct HealthDiaryApp: App {

    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
        PantryItem.self,
        IngredientAlias.self,
    ]

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(allModels)

        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // マイグレーション失敗時は旧ストアを削除して再作成
        purgeStores()
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("SwiftData: ストア再作成にも失敗しました: \(error)")
        }
    }

    private static func purgeStores() {
        let fm = FileManager.default
        let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let exts = ["sqlite", "sqlite-wal", "sqlite-shm"]
        for ext in exts {
            let url = supportDir.appendingPathComponent("default.store").appendingPathExtension(ext)
            try? fm.removeItem(at: url)
        }
        if let contents = try? fm.contentsOfDirectory(at: supportDir, includingPropertiesForKeys: nil) {
            for file in contents where exts.contains(file.pathExtension) {
                try? fm.removeItem(at: file)
            }
        }
    }
}
