import XCTest
@testable import HealthDiary

final class HealthDiaryTests: XCTestCase {

    func testMealHistoryEntryCreation() {
        let entry = MealHistoryEntry(
            recipeName: "カレー",
            cuisineType: .western,
            mainIngredient: .meat,
            cookingMethod: .simmer
        )
        XCTAssertEqual(entry.recipeName, "カレー")
        XCTAssertEqual(entry.cuisineType, .western)
    }

    func testShoppingItemInitialization() {
        let item = ShoppingItem(name: "鶏肉", totalAmount: 300, unit: "g", category: .meatFish)
        XCTAssertFalse(item.isChecked)
        XCTAssertTrue(item.usedInRecipes.isEmpty)
    }

    func testFoodLogEntryTotalCalories() {
        let entry = FoodLogEntry(mealType: .dinner, recipeName: "唐揚げ", caloriesPerServing: 400, servings: 1.5)
        XCTAssertEqual(entry.totalCalories, 600)
    }

    func testActivityGoalDefaults() {
        let goal = ActivityGoal()
        XCTAssertEqual(goal.dailySteps, 8000)
        XCTAssertEqual(goal.dailyActiveCalories, 500)
    }
}
