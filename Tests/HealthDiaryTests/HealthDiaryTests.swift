import XCTest
@testable import HealthDiary

final class HealthDiaryTests: XCTestCase {

    func testMealPlanCreation() {
        let plan = MealPlan(startDate: Date())
        XCTAssertNotNil(plan.id)
        XCTAssertTrue(plan.days.isEmpty)
    }

    func testRecipeWithLeftovers() {
        let recipe = Recipe(name: "カレー", servings: 4, extraServings: 2)
        XCTAssertEqual(recipe.extraServings, 2)
    }
}
