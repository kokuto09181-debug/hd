import Foundation
import SwiftData

@Model
final class FoodLogEntry {
    var loggedAt: Date
    var mealType: MealType
    var recipeID: String?
    var recipeName: String
    var caloriesPerServing: Double
    var servings: Double
    var source: FoodLogSource

    var totalCalories: Double {
        caloriesPerServing * servings
    }

    init(mealType: MealType, recipeName: String, caloriesPerServing: Double, servings: Double = 1.0, source: FoodLogSource = .manual, recipeID: String? = nil) {
        self.loggedAt = Date()
        self.mealType = mealType
        self.recipeName = recipeName
        self.caloriesPerServing = caloriesPerServing
        self.servings = servings
        self.source = source
        self.recipeID = recipeID
    }
}
