import Foundation

enum MealType: String, Codable, CaseIterable {
    case breakfast = "朝食"
    case lunch = "昼食"
    case dinner = "夕食"
    case snack = "間食"
}

enum MealOption: String, Codable {
    case homeCooked = "自炊"
    case diningOut = "外食"
    case skipped = "スキップ"
}

enum MealPlanStatus: String, Codable {
    case draft = "draft"
    case shopping = "shopping"  // 買い出し済み（旧 .confirmed）

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "shopping", "確定", "confirmed": self = .shopping
        case "draft", "下書き": self = .draft
        default: self = .draft
        }
    }
}

enum CuisineType: String, Codable, CaseIterable {
    case japanese = "和食"
    case western = "洋食"
    case chinese = "中華"
    case ethnic = "エスニック"
    case other = "その他"
}

enum MainIngredientCategory: String, Codable, CaseIterable {
    case meat = "肉"
    case fish = "魚"
    case vegetable = "野菜"
    case tofu = "豆腐"
    case egg = "卵"
    case other = "その他"
}

enum CookingMethod: String, Codable, CaseIterable {
    case grill = "焼く"
    case simmer = "煮る"
    case stirFry = "炒める"
    case fry = "揚げる"
    case raw = "生"
    case steam = "蒸す"
    case other = "その他"
}

enum IngredientCategory: String, Codable, CaseIterable {
    case meatFish = "肉・魚"
    case vegetable = "野菜"
    case dairy = "乳製品・卵"
    case seasoning = "調味料"
    case grain = "穀物・麺類"
    case other = "その他"
}

enum AgeGroup: String, Codable, CaseIterable {
    case adult = "大人"
    case child = "子供"
    case infant = "乳幼児"
}

enum FoodLogSource: String, Codable {
    case recipe = "レシピから"
    case photo = "写真から"
    case manual = "手動入力"
}

enum WorkoutType: String, Codable, CaseIterable {
    case running = "ランニング"
    case walking = "ウォーキング"
    case cycling = "サイクリング"
    case swimming = "水泳"
    case strength = "筋トレ"
    case yoga = "ヨガ"
    case other = "その他"
}

enum ChatContext: String, Codable {
    case recipe = "レシピ"
    case mealPlan = "献立"
    case leftover = "残り物"
    case health = "健康相談"
    case free = "自由相談"
}

enum ChatRole: String, Codable {
    case user
    case assistant
}
