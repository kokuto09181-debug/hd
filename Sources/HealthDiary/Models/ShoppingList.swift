import Foundation
import SwiftData

@Model
final class ShoppingList {
    var mealPlanID: UUID
    var generatedAt: Date
    @Relationship(deleteRule: .cascade) var items: [ShoppingItem]

    init(mealPlanID: UUID) {
        self.mealPlanID = mealPlanID
        self.generatedAt = Date()
        self.items = []
    }
}

@Model
final class ShoppingItem {
    var name: String
    var totalAmount: Double
    var unit: String
    var category: IngredientCategory
    var isChecked: Bool
    var usedInRecipes: [String]

    init(name: String, totalAmount: Double, unit: String, category: IngredientCategory) {
        self.name = name
        self.totalAmount = totalAmount
        self.unit = unit
        self.category = category
        self.isChecked = false
        self.usedInRecipes = []
    }
}
