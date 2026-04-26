import Foundation
import SwiftData

@Model
final class PantryItem {
    var name: String
    var amount: Double?       // nil = あるかどうかだけ管理
    var unit: String?
    var category: IngredientCategory
    var addedAt: Date
    var source: PantrySource

    init(
        name: String,
        amount: Double? = nil,
        unit: String? = nil,
        category: IngredientCategory = .other,
        source: PantrySource = .manual
    ) {
        self.name = name
        self.amount = amount
        self.unit = unit
        self.category = category
        self.addedAt = Date()
        self.source = source
    }
}

/// LLMが学習した食材名の別名（正規化テーブルへの追記）
@Model
final class IngredientAlias {
    var alias: String       // 例: "タマネギ"
    var canonical: String   // 例: "玉ねぎ"
    var addedAt: Date

    init(alias: String, canonical: String) {
        self.alias = alias.lowercased()
        self.canonical = canonical
        self.addedAt = Date()
    }
}
