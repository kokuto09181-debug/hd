import Foundation

struct MealPlan: Identifiable, Codable {
    let id: UUID
    var startDate: Date
    var days: [DayPlan]

    init(id: UUID = UUID(), startDate: Date, days: [DayPlan] = []) {
        self.id = id
        self.startDate = startDate
        self.days = days
    }
}

struct DayPlan: Identifiable, Codable {
    let id: UUID
    var date: Date
    var meals: [Meal]

    init(id: UUID = UUID(), date: Date, meals: [Meal] = []) {
        self.id = id
        self.date = date
        self.meals = meals
    }
}

struct Meal: Identifiable, Codable {
    let id: UUID
    var type: MealType
    var recipe: Recipe?
    var leftoverSourceID: UUID?
    var notes: String

    init(id: UUID = UUID(), type: MealType, recipe: Recipe? = nil, leftoverSourceID: UUID? = nil, notes: String = "") {
        self.id = id
        self.type = type
        self.recipe = recipe
        self.leftoverSourceID = leftoverSourceID
        self.notes = notes
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "朝食"
    case lunch = "昼食"
    case dinner = "夕食"
    case snack = "間食"
}

struct Recipe: Identifiable, Codable {
    let id: UUID
    var name: String
    var servings: Int
    var extraServings: Int
    var ingredients: [Ingredient]
    var caloriesPerServing: Double

    init(id: UUID = UUID(), name: String, servings: Int = 2, extraServings: Int = 0, ingredients: [Ingredient] = [], caloriesPerServing: Double = 0) {
        self.id = id
        self.name = name
        self.servings = servings
        self.extraServings = extraServings
        self.ingredients = ingredients
        self.caloriesPerServing = caloriesPerServing
    }
}

struct Ingredient: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var unit: String

    init(id: UUID = UUID(), name: String, amount: Double, unit: String) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}
