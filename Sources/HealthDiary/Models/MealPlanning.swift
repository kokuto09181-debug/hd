import Foundation
import SwiftData

@Model
final class MealPlan {
    var startDate: Date
    var endDate: Date
    var status: MealPlanStatus
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var days: [DayPlan]

    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
        self.status = .draft
        self.createdAt = Date()
        self.days = []
    }
}

@Model
final class DayPlan {
    var date: Date
    @Relationship(deleteRule: .cascade) var meals: [PlannedMeal]

    init(date: Date) {
        self.date = date
        self.meals = []
    }
}

@Model
final class PlannedMeal {
    var mealType: MealType
    var mealOption: MealOption
    var recipeID: String?
    var recipeName: String?
    var recipeURL: String?
    var leftoverSourceMealID: UUID?
    var notes: String

    init(mealType: MealType, mealOption: MealOption = .homeCooked) {
        self.mealType = mealType
        self.mealOption = mealOption
        self.notes = ""
    }
}

// 献立の多様性管理のための履歴（ルールベース用）
@Model
final class MealHistoryEntry {
    var recipeName: String
    var recipeID: String?
    var cuisineType: CuisineType
    var mainIngredient: MainIngredientCategory
    var cookingMethod: CookingMethod
    var servedAt: Date

    init(recipeName: String, cuisineType: CuisineType, mainIngredient: MainIngredientCategory, cookingMethod: CookingMethod, recipeID: String? = nil) {
        self.recipeName = recipeName
        self.cuisineType = cuisineType
        self.mainIngredient = mainIngredient
        self.cookingMethod = cookingMethod
        self.recipeID = recipeID
        self.servedAt = Date()
    }
}
