import Foundation
import SQLite3

final class RecipeDatabase {
    static let shared = RecipeDatabase()
    private var db: OpaquePointer?

    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        openDatabase()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        guard let path = Bundle.main.path(forResource: "recipes", ofType: "sqlite") else { return }
        sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
    }

    var isAvailable: Bool { db != nil }

    // MARK: - Recipe Queries

    func fetchRecipes(
        cuisineType: CuisineType,
        mainIngredient: MainIngredientCategory,
        cookingMethod: CookingMethod? = nil,
        excludeIDs: [String] = [],
        limit: Int = 20
    ) -> [RecipeRecord] {
        guard let db else { return [] }

        var conditions = ["cuisine_type = ?", "main_ingredient = ?"]
        if cookingMethod != nil { conditions.append("cooking_method = ?") }

        let query = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes
            WHERE \(conditions.joined(separator: " AND "))
            ORDER BY RANDOM()
            LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1
        sqlite3_bind_text(statement, bindIndex, cuisineType.rawValue, -1, SQLITE_TRANSIENT)
        bindIndex += 1
        sqlite3_bind_text(statement, bindIndex, mainIngredient.rawValue, -1, SQLITE_TRANSIENT)
        bindIndex += 1
        if let method = cookingMethod {
            sqlite3_bind_text(statement, bindIndex, method.rawValue, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }
        sqlite3_bind_int(statement, bindIndex, Int32(limit))

        var recipes: [RecipeRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let record = parseRecipeRow(statement) else { continue }
            if !excludeIDs.contains(record.id) {
                recipes.append(record)
            }
        }
        return recipes
    }

    /// LLMプロンプト用に全レシピを取得（ランダム順）
    func fetchAll(limit: Int = 150) -> [RecipeRecord] {
        guard let db else { return [] }
        let query = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes
            ORDER BY RANDOM()
            LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))
        var recipes: [RecipeRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = parseRecipeRow(statement) { recipes.append(record) }
        }
        return recipes
    }

    /// IDでレシピを1件取得（JSONパース後の照合用）
    func findByID(_ id: String) -> RecipeRecord? {
        guard let db else { return nil }
        let query = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes WHERE id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
        if sqlite3_step(statement) == SQLITE_ROW { return parseRecipeRow(statement) }
        return nil
    }

    /// LLMプロンプト用に全レシピをランダム順で取得
    func fetchAll(limit: Int = 150) -> [RecipeRecord] {
        guard let db else { return [] }
        let query = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes
            ORDER BY RANDOM()
            LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))
        var recipes: [RecipeRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = parseRecipeRow(statement) { recipes.append(record) }
        }
        return recipes
    }

    /// IDでレシピを1件取得（JSONパース後の照合用）
    func findByID(_ id: String) -> RecipeRecord? {
        guard let db else { return nil }
        let query = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes WHERE id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
        if sqlite3_step(statement) == SQLITE_ROW { return parseRecipeRow(statement) }
        return nil
    }

    func fetchIngredients(for recipeID: String) -> [IngredientRecord] {
        guard let db else { return [] }

        let query = "SELECT id, recipe_id, name, amount, unit, category FROM ingredients WHERE recipe_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, recipeID, -1, SQLITE_TRANSIENT)

        var ingredients: [IngredientRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            ingredients.append(IngredientRecord(
                id: columnString(statement, 0),
                recipeID: columnString(statement, 1),
                name: columnString(statement, 2),
                amount: sqlite3_column_double(statement, 3),
                unit: columnString(statement, 4),
                category: IngredientCategory(rawValue: columnString(statement, 5)) ?? .other
            ))
        }
        return ingredients
    }

    // MARK: - Helpers

    private func parseRecipeRow(_ statement: OpaquePointer?) -> RecipeRecord? {
        guard let statement else { return nil }
        return RecipeRecord(
            id: columnString(statement, 0),
            name: columnString(statement, 1),
            url: columnString(statement, 2),
            cuisineType: CuisineType(rawValue: columnString(statement, 3)) ?? .other,
            mainIngredient: MainIngredientCategory(rawValue: columnString(statement, 4)) ?? .other,
            cookingMethod: CookingMethod(rawValue: columnString(statement, 5)) ?? .other,
            caloriesPerServing: sqlite3_column_double(statement, 6),
            servingSize: Int(sqlite3_column_int(statement, 7)),
            ingredients: []
        )
    }

    private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }
}
