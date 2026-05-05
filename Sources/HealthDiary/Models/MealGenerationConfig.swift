import Foundation

// MARK: - Soup Style

/// 汁物のスタイル区分
enum SoupStyle: String, Codable, CaseIterable {
    case japanese = "和風汁物"   // 汁・みそ系
    case western  = "洋風スープ" // スープ・ポタージュ系
    case any      = "どちらでも"
}

// MARK: - Main Dish Spec

/// メイン料理のDB検索方法
struct MainDishSpec: Codable, Equatable {
    enum SpecType: String, Codable {
        case byIngredient   // 食材カテゴリ + 料理系統で絞る
        case byKeyword      // 料理名のキーワードで絞る（パン系など）
    }

    var type: SpecType
    var ingredients: [MainIngredientCategory] // .byIngredient 時に使用
    var cuisines: [CuisineType]               // .byIngredient 時に使用（空 = すべて）
    var keywords: [String]                    // .byKeyword 時に使用

    // MARK: Factory

    static func ingredient(
        _ ingredients: [MainIngredientCategory],
        cuisines: [CuisineType] = []
    ) -> MainDishSpec {
        MainDishSpec(type: .byIngredient, ingredients: ingredients, cuisines: cuisines, keywords: [])
    }

    static func keyword(_ keywords: [String]) -> MainDishSpec {
        MainDishSpec(type: .byKeyword, ingredients: [], cuisines: [], keywords: keywords)
    }

    // MARK: Display

    var displayDescription: String {
        switch type {
        case .byIngredient:
            let ingText = ingredients.map { $0.rawValue }.joined(separator: "・")
            let cusText = cuisines.isEmpty ? "" : "（\(cuisines.map { $0.rawValue }.joined(separator: "・"))）"
            return ingText + cusText
        case .byKeyword:
            return keywords.prefix(3).joined(separator: "・")
        }
    }
}

// MARK: - Meal Slot Template

/// 1食分の構成を定義するテンプレート
struct MealSlotTemplate: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var emoji: String
    /// メイン料理の検索仕様
    var mainDishSpec: MainDishSpec
    /// 副菜を加えるか（昼食・夕食向け）
    var sideDishEnabled: Bool
    /// 汁物を加えるか
    var soupEnabled: Bool
    /// 汁物のスタイル（soupEnabled = true の時のみ使用）
    var soupStyle: SoupStyle

    /// 構成の一行サマリー
    var summary: String {
        var parts = [mainDishSpec.displayDescription]
        if sideDishEnabled { parts.append("副菜") }
        if soupEnabled     { parts.append(soupStyle.rawValue) }
        return parts.joined(separator: " + ")
    }
}

// MARK: - Built-in Slot Presets

extension MealSlotTemplate {

    // ── 朝食 ─────────────────────────────────

    static let simpleBreakfast = MealSlotTemplate(
        name: "シンプル朝食", emoji: "🌅",
        mainDishSpec: .ingredient([.egg, .tofu, .vegetable]),
        sideDishEnabled: false, soupEnabled: false, soupStyle: .any
    )
    static let japaneseBreakfast = MealSlotTemplate(
        name: "和朝食", emoji: "🍱",
        mainDishSpec: .ingredient([.fish, .egg, .tofu], cuisines: [.japanese]),
        sideDishEnabled: true, soupEnabled: true, soupStyle: .japanese
    )
    static let breadBreakfast = MealSlotTemplate(
        name: "パン朝食", emoji: "🍞",
        mainDishSpec: .keyword(["パン", "トースト", "サンド", "フレンチトースト", "ホットケーキ"]),
        sideDishEnabled: false, soupEnabled: false, soupStyle: .western
    )
    static let heartyBreakfast = MealSlotTemplate(
        name: "がっつり朝食", emoji: "💪",
        mainDishSpec: .ingredient([.meat, .egg]),
        sideDishEnabled: false, soupEnabled: false, soupStyle: .any
    )

    static let breakfastPresets: [MealSlotTemplate] = [
        .simpleBreakfast, .japaneseBreakfast, .breadBreakfast, .heartyBreakfast
    ]

    // ── 昼食 ─────────────────────────────────

    static let lunchTeishoku = MealSlotTemplate(
        name: "定食（昼）", emoji: "🍚",
        mainDishSpec: .ingredient([.meat, .fish]),
        sideDishEnabled: true, soupEnabled: false, soupStyle: .any
    )
    static let noodleBowl = MealSlotTemplate(
        name: "麺・丼", emoji: "🍜",
        mainDishSpec: .keyword(["麺", "丼", "ラーメン", "うどん", "そば", "パスタ", "焼きそば", "チャーハン"]),
        sideDishEnabled: false, soupEnabled: false, soupStyle: .any
    )
    static let westernLunch = MealSlotTemplate(
        name: "洋昼食", emoji: "🍽️",
        mainDishSpec: .ingredient([.meat, .fish], cuisines: [.western]),
        sideDishEnabled: true, soupEnabled: false, soupStyle: .western
    )
    static let chineseLunch = MealSlotTemplate(
        name: "中華昼食", emoji: "🥢",
        mainDishSpec: .ingredient([.meat, .fish], cuisines: [.chinese]),
        sideDishEnabled: false, soupEnabled: false, soupStyle: .any
    )

    static let lunchPresets: [MealSlotTemplate] = [
        .lunchTeishoku, .noodleBowl, .westernLunch, .chineseLunch
    ]

    // ── 夕食 ─────────────────────────────────

    static let balancedDinner = MealSlotTemplate(
        name: "バランス夕食", emoji: "⚖️",
        mainDishSpec: .ingredient([.meat, .fish]),
        sideDishEnabled: true, soupEnabled: true, soupStyle: .any
    )
    static let japaneseDinner = MealSlotTemplate(
        name: "和夕食定食", emoji: "🎌",
        mainDishSpec: .ingredient([.meat, .fish], cuisines: [.japanese]),
        sideDishEnabled: true, soupEnabled: true, soupStyle: .japanese
    )
    static let westernDinner = MealSlotTemplate(
        name: "洋夕食", emoji: "🍷",
        mainDishSpec: .ingredient([.meat, .fish], cuisines: [.western]),
        sideDishEnabled: true, soupEnabled: true, soupStyle: .western
    )
    static let chineseDinner = MealSlotTemplate(
        name: "中華夕食", emoji: "🥡",
        mainDishSpec: .ingredient([.meat, .fish], cuisines: [.chinese]),
        sideDishEnabled: true, soupEnabled: false, soupStyle: .any
    )

    static let dinnerPresets: [MealSlotTemplate] = [
        .balancedDinner, .japaneseDinner, .westernDinner, .chineseDinner
    ]

    // MARK: Lookup

    static func presets(for mealType: MealType) -> [MealSlotTemplate] {
        switch mealType {
        case .breakfast: return breakfastPresets
        case .lunch:     return lunchPresets
        case .dinner:    return dinnerPresets
        case .snack:     return [simpleBreakfast]
        }
    }
}

// MARK: - Meal Generation Config

/// 全食事スロット（平日・休日 × 朝昼夕）の構成設定
struct MealGenerationConfig: Codable, Equatable {
    var breakfastWeekday: MealSlotTemplate
    var breakfastWeekend: MealSlotTemplate
    var lunchWeekday:     MealSlotTemplate
    var lunchWeekend:     MealSlotTemplate
    var dinnerWeekday:    MealSlotTemplate
    var dinnerWeekend:    MealSlotTemplate

    /// 特定の食事スロットに対応するテンプレートを返す
    func template(for mealType: MealType, isWeekend: Bool) -> MealSlotTemplate {
        switch mealType {
        case .breakfast: return isWeekend ? breakfastWeekend : breakfastWeekday
        case .lunch:     return isWeekend ? lunchWeekend     : lunchWeekday
        case .dinner:    return isWeekend ? dinnerWeekend    : dinnerWeekday
        case .snack:
            return MealSlotTemplate(
                name: "おやつ", emoji: "🍪",
                mainDishSpec: .ingredient([.other]),
                sideDishEnabled: false, soupEnabled: false, soupStyle: .any
            )
        }
    }

    // MARK: Built-in overall presets

    static let balanced = MealGenerationConfig(
        breakfastWeekday: .simpleBreakfast,
        breakfastWeekend: .simpleBreakfast,
        lunchWeekday:     .lunchTeishoku,
        lunchWeekend:     .lunchTeishoku,
        dinnerWeekday:    .balancedDinner,
        dinnerWeekend:    .balancedDinner
    )
    static let japanese = MealGenerationConfig(
        breakfastWeekday: .japaneseBreakfast,
        breakfastWeekend: .japaneseBreakfast,
        lunchWeekday:     .lunchTeishoku,
        lunchWeekend:     .lunchTeishoku,
        dinnerWeekday:    .japaneseDinner,
        dinnerWeekend:    .japaneseDinner
    )
    static let western = MealGenerationConfig(
        breakfastWeekday: .breadBreakfast,
        breakfastWeekend: .breadBreakfast,
        lunchWeekday:     .westernLunch,
        lunchWeekend:     .westernLunch,
        dinnerWeekday:    .westernDinner,
        dinnerWeekend:    .westernDinner
    )
}

// MARK: - Overall Presets

extension MealGenerationConfig {
    struct Preset: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        let config: MealGenerationConfig
    }

    static let overallPresets: [Preset] = [
        Preset(name: "バランス", emoji: "⚖️", config: .balanced),
        Preset(name: "和食中心", emoji: "🎌", config: .japanese),
        Preset(name: "洋食中心", emoji: "🍷", config: .western),
    ]

    /// 現在の設定がいずれかのプリセットと完全一致するなら、そのプリセット名を返す
    var matchingPresetName: String? {
        MealGenerationConfig.overallPresets.first { $0.config == self }?.name
    }
}

// MARK: - Settings Storage

/// UserDefaults に献立スタイル設定を永続化するシングルトン
final class MealGenerationSettings: ObservableObject {
    static let shared = MealGenerationSettings()

    private let key = "mealGenerationConfig_v1"

    @Published var config: MealGenerationConfig {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(MealGenerationConfig.self, from: data) {
            config = decoded
        } else {
            config = .balanced
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func apply(_ preset: MealGenerationConfig) {
        config = preset
    }
}
