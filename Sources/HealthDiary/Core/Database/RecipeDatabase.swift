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
    func fetchAll(limit: Int = 30) -> [RecipeRecord] {
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

    /// 完全一致でレシピを1件取得（LLM出力のDB照合用）
    func findByName(_ name: String) -> RecipeRecord? {
        guard let db, !name.isEmpty else { return nil }
        let sql = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes WHERE name = ? LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT)
        if sqlite3_step(statement) == SQLITE_ROW { return parseRecipeRow(statement) }
        return nil
    }

    /// LLMが生成した料理名からDBの近いレシピを検索。
    /// 「DBレシピ名がqueryに含まれる」または「queryがDBレシピ名に含まれる」でマッチ。
    /// 完全一致でなくてもよい（例: "鶏の唐揚げ定食" → DB "唐揚げ" にマッチ）。
    func searchByName(_ query: String) -> RecipeRecord? {
        guard let db, !query.isEmpty else { return nil }
        let sql = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes
            WHERE ? LIKE '%' || name || '%'
               OR name LIKE '%' || ? || '%'
            ORDER BY LENGTH(name) DESC
            LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, query, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, query, -1, SQLITE_TRANSIENT)
        if sqlite3_step(statement) == SQLITE_ROW { return parseRecipeRow(statement) }
        return nil
    }

    /// フリーテキスト検索（レシピ選択UI用）
    /// queryが空の場合はランダムで件数分返す
    func searchRecipes(query: String, limit: Int = 30) -> [RecipeRecord] {
        guard let db else { return [] }
        let sql: String
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            sql = """
                SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                       calories_per_serving, serving_size
                FROM recipes ORDER BY name ASC LIMIT \(limit)
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(statement) }
            var recipes: [RecipeRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let r = parseRecipeRow(statement) { recipes.append(r) }
            }
            return recipes
        } else {
            let sql2 = """
                SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                       calories_per_serving, serving_size
                FROM recipes
                WHERE name LIKE '%' || ? || '%'
                ORDER BY LENGTH(name) ASC LIMIT ?
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql2, -1, &statement, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, query, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(limit))
            var recipes: [RecipeRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let r = parseRecipeRow(statement) { recipes.append(r) }
            }
            return recipes
        }
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

    /// 副菜用: 野菜・豆腐・卵メインのレシピをランダムに1件取得
    func fetchSideDish(excludeIDs: [String] = []) -> RecipeRecord? {
        guard let db else { return nil }
        let exclusionClause = excludeIDs.isEmpty ? ""
            : " AND id NOT IN (\(excludeIDs.map { _ in "?" }.joined(separator: ",")))"
        let sql = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes
            WHERE main_ingredient IN ('野菜', '豆腐', '卵')
            \(exclusionClause)
            ORDER BY RANDOM() LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        for (i, id) in excludeIDs.enumerated() {
            sqlite3_bind_text(statement, Int32(i + 1), id, -1, SQLITE_TRANSIENT)
        }
        if sqlite3_step(statement) == SQLITE_ROW { return parseRecipeRow(statement) }
        return nil
    }

    /// 汁物用: 名前に「汁」「スープ」「ポタージュ」「みそ」を含むレシピをランダムに1件取得
    func fetchSoup(excludeIDs: [String] = []) -> RecipeRecord? {
        guard let db else { return nil }
        let exclusionClause = excludeIDs.isEmpty ? ""
            : " AND id NOT IN (\(excludeIDs.map { _ in "?" }.joined(separator: ",")))"
        let sql = """
            SELECT id, name, url, cuisine_type, main_ingredient, cooking_method,
                   calories_per_serving, serving_size
            FROM recipes
            WHERE (name LIKE '%汁%' OR name LIKE '%スープ%'
                OR name LIKE '%ポタージュ%' OR name LIKE '%みそ%')
            \(exclusionClause)
            ORDER BY RANDOM() LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        for (i, id) in excludeIDs.enumerated() {
            sqlite3_bind_text(statement, Int32(i + 1), id, -1, SQLITE_TRANSIENT)
        }
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
