import Foundation
import SwiftData

final class MealPlanEngine {

    // MARK: - Plan Generation

    func generatePlan(
        startDate: Date,
        numberOfDays: Int,
        slotConfig: SlotConfig,
        history: [MealHistoryEntry],
        profile: FamilyProfile?,
        context: ModelContext
    ) -> MealPlan {
        let endDate = Calendar.current.date(byAdding: .day, value: numberOfDays - 1, to: startDate)!
        let plan = MealPlan(startDate: startDate, endDate: endDate)
        context.insert(plan)

        let recentIDs = Set(history.map { $0.recipeID }.compactMap { $0 })
        var usedIDs = recentIDs
        var cuisineRotation = CuisineRotation(history: history)
        var methodRotation = CookingMethodRotation(history: history)

        for dayOffset in 0..<numberOfDays {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate)!
            let dayPlan = DayPlan(date: date)
            context.insert(dayPlan)

            let isWeekend = Calendar.current.isDateInWeekend(date)
            let slots = isWeekend ? slotConfig.weekend : slotConfig.weekday

            for mealType in slots {
                let meal = PlannedMeal(mealType: mealType)

                if let recipe = pickRecipe(
                    mealType: mealType,
                    cuisineRotation: &cuisineRotation,
                    methodRotation: &methodRotation,
                    excludeIDs: Array(usedIDs),
                    profile: profile
                ) {
                    meal.recipeID = recipe.id
                    meal.recipeName = recipe.name
                    meal.recipeURL = recipe.url
                    usedIDs.insert(recipe.id)
                    cuisineRotation.record(recipe.cuisineType)
                    methodRotation.record(recipe.cookingMethod)
                }

                dayPlan.meals.append(meal)
            }

            plan.days.append(dayPlan)
        }

        return plan
    }

    // MARK: - Recipe Picking (Rule-based + DB)

    private func pickRecipe(
        mealType: MealType,
        cuisineRotation: inout CuisineRotation,
        methodRotation: inout CookingMethodRotation,
        excludeIDs: [String],
        profile: FamilyProfile?
    ) -> RecipeRecord? {
        guard RecipeDatabase.shared.isAvailable else { return nil }

        let targetCuisine = cuisineRotation.next()
        let targetIngredient = MainIngredientCategory.allCases.randomElement() ?? .other
        let targetMethod = methodRotation.next()

        var candidates = RecipeDatabase.shared.fetchRecipes(
            cuisineType: targetCuisine,
            mainIngredient: targetIngredient,
            cookingMethod: targetMethod,
            excludeIDs: excludeIDs
        )

        // 条件を緩めて再検索
        if candidates.isEmpty {
            candidates = RecipeDatabase.shared.fetchRecipes(
                cuisineType: targetCuisine,
                mainIngredient: targetIngredient,
                excludeIDs: excludeIDs
            )
        }
        if candidates.isEmpty {
            candidates = RecipeDatabase.shared.fetchRecipes(
                cuisineType: targetCuisine,
                mainIngredient: targetIngredient
            )
        }

        return candidates.first
    }

    // MARK: - Shopping List Generation

    func generateShoppingList(
        from plan: MealPlan,
        context: ModelContext,
        aliases: [IngredientAlias] = []
    ) -> ShoppingList {
        let list = ShoppingList(mealPlanID: plan.id)
        context.insert(list)

        let normService = IngredientNormalizationService.shared
        // key = "正規化名_単位" で集計
        var aggregated: [String: AggregatedIngredient] = [:]

        for day in plan.days {
            for meal in day.meals {
                guard let recipeID = meal.recipeID, let recipeName = meal.recipeName else { continue }
                let ingredients = RecipeDatabase.shared.fetchIngredients(for: recipeID)
                for ing in ingredients {
                    let canonical = normService.normalize(ing.name, aliases: aliases)
                    let key = "\(canonical)_\(ing.unit)"
                    if aggregated[key] != nil {
                        aggregated[key]!.totalAmount += ing.amount
                        aggregated[key]!.usedInRecipes.insert(recipeName)
                    } else {
                        aggregated[key] = AggregatedIngredient(
                            name: canonical,
                            totalAmount: ing.amount,
                            unit: ing.unit,
                            category: ing.category,
                            usedInRecipes: [recipeName]
                        )
                    }
                }
            }
        }

        for agg in aggregated.values {
            let item = ShoppingItem(name: agg.name, totalAmount: agg.totalAmount, unit: agg.unit, category: agg.category)
            item.usedInRecipes = Array(agg.usedInRecipes).sorted()
            context.insert(item)
            list.items.append(item)
        }

        list.items.sort { $0.category.rawValue < $1.category.rawValue }
        return list
    }
}

// MARK: - Supporting Types

struct SlotConfig {
    var weekday: [MealType] = [.breakfast, .dinner]
    var weekend: [MealType] = [.breakfast, .lunch, .dinner]
}

private struct AggregatedIngredient {
    var name: String
    var totalAmount: Double
    var unit: String
    var category: IngredientCategory
    var usedInRecipes: Set<String>
}

// MARK: - Rotation Logic

private struct CuisineRotation {
    private var queue: [CuisineType]
    private var index = 0

    init(history: [MealHistoryEntry]) {
        let recent = history.suffix(14).map { $0.cuisineType }
        // 直近で少ない系統を優先
        queue = CuisineType.allCases.sorted { a, b in
            recent.filter { $0 == a }.count < recent.filter { $0 == b }.count
        }
    }

    mutating func next() -> CuisineType {
        let value = queue[index % queue.count]
        index += 1
        return value
    }

    mutating func record(_ type: CuisineType) {
        // 使った系統を末尾に移動
        if let i = queue.firstIndex(of: type) {
            queue.remove(at: i)
            queue.append(type)
        }
    }
}

private struct CookingMethodRotation {
    private var lastMethod: CookingMethod? = nil

    init(history: [MealHistoryEntry]) {
        lastMethod = history.last?.cookingMethod
    }

    mutating func next() -> CookingMethod? {
        // 同じ調理法が連続しないよう前回と異なるものを返す
        let options = CookingMethod.allCases.filter { $0 != lastMethod }
        return options.randomElement()
    }

    mutating func record(_ method: CookingMethod) {
        lastMethod = method
    }
}
