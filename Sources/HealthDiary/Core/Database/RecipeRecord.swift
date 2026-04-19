import Foundation

struct RecipeRecord: Identifiable {
    let id: String
    let name: String
    let url: String
    let cuisineType: CuisineType
    let mainIngredient: MainIngredientCategory
    let cookingMethod: CookingMethod
    let caloriesPerServing: Double
    let servingSize: Int
    var ingredients: [IngredientRecord]
}

struct IngredientRecord: Identifiable {
    let id: String
    let recipeID: String
    let name: String
    let amount: Double
    let unit: String
    let category: IngredientCategory
}
