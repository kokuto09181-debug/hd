import Foundation
import SwiftData

/// LLMを使った献立生成サービス
@MainActor
final class LLMPlanGenerator {

    static let shared = LLMPlanGenerator()
    private init() {}

    struct GenerationRequest {
        let numberOfDays: Int
        let startDate: Date
        let slotConfig: SlotConfig
        let familyProfile: FamilyProfile?
        let recentHistory: [MealHistoryEntry]
        let conditions: [String]
    }

    enum GenerationError: LocalizedError {
        case modelNotLoaded
        case invalidJSON(String)
        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "AIモデルがまだ読み込まれていません"
            case .invalidJSON(let msg): return "献立の生成に失敗しました: \(msg)"
            }
        }
    }

    func generate(request: GenerationRequest, context: ModelContext) async throws -> MealPlan {
        let recipes = RecipeDatabase.shared.fetchAll(limit: 150)
        let prompt = buildPrompt(request: request, recipes: recipes)
        let llmCtx = LLMContext.mealPlan(
            days: request.numberOfDays,
            familySize: request.familyProfile?.members.count ?? 1
        )
        let jsonText = try await LLMService.shared.generate(prompt: prompt, context: llmCtx)
        return try parsePlanJSON(jsonText, request: request, context: context)
    }

    // 特定の1日だけ再生成
    func regenerateDay(
        dayPlan: DayPlan,
        plan: MealPlan,
        request: GenerationRequest,
        context: ModelContext
    ) async throws {
        let recipes = RecipeDatabase.shared.fetchAll(limit: 150)
        let prompt = buildDayPrompt(dayPlan: dayPlan, plan: plan, request: request, recipes: recipes)
        let llmCtx = LLMContext.mealPlan(
            days: 1,
            familySize: request.familyProfile?.members.count ?? 1
        )
        let jsonText = try await LLMService.shared.generate(prompt: prompt, context: llmCtx)
        try parseDayJSON(jsonText, into: dayPlan, context: context)
    }

    // MARK: - Public Methods (for MealPlanDetailView)

    func buildPublicPrompt(request: GenerationRequest, recipes: [RecipeRecord]) -> String {
        buildPrompt(request: request, recipes: recipes)
    }

    func applyPlanJSON(_ text: String, to plan: MealPlan, request: GenerationRequest, context: ModelContext) throws {
        let data = try extractJSON(from: text)
        let response = try JSONDecoder().decode(PlanResponse.self, from: data)
        for dayResp in response.days {
            let date = parseDate(dayResp.date) ?? request.startDate
            let dayPlan = DayPlan(date: date)
            context.insert(dayPlan)
            appendMeals(from: dayResp.meals, to: dayPlan, context: context)
            plan.days.append(dayPlan)
        }
    }

    // MARK: - Prompt Building

    private func buildPrompt(request: GenerationRequest, recipes: [RecipeRecord]) -> String {
        let familyText = buildFamilyText(request.familyProfile)
        let conditionsText = request.conditions.isEmpty ? "特になし" : request.conditions.joined(separator: "\n")
        let recentIDs = request.recentHistory.prefix(30).compactMap { $0.recipeID }
        let recentText = recentIDs.isEmpty ? "なし" : recentIDs.joined(separator: ", ")
        let recipeLines = recipes.map { r in
            "ID:\(r.id) 名前:\(r.name) 種別:\(r.cuisineType.rawValue) 主材料:\(r.mainIngredient.rawValue) 調理法:\(r.cookingMethod.rawValue) カロリー:\(Int(r.caloriesPerServing))kcal"
        }.joined(separator: "\n")
        let slotsText = buildSlotsText(request: request)

        return """
        あなたは家族向け献立提案アシスタントです。
        以下の情報をもとに献立を提案してください。

        【家族情報】
        \(familyText)

        【希望条件】
        \(conditionsText)

        【各日の食事スロット】
        \(slotsText)

        【直近で食べたレシピID（なるべく避けること）】
        \(recentText)

        【選択可能なレシピ一覧】
        \(recipeLines)

        【出力形式】
        必ず以下のJSONのみ出力。説明文・前置き・コードブロック記号は不要。
        {
          "days": [
            {
              "date": "YYYY-MM-DD",
              "meals": {
                "breakfast": {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""},
                "lunch": {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""},
                "dinner": {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""}
              }
            }
          ]
        }
        スロット外の食事はキーを省略。recipe_idはリスト内のIDのみ使用。
        """
    }

    private func buildDayPrompt(
        dayPlan: DayPlan,
        plan: MealPlan,
        request: GenerationRequest,
        recipes: [RecipeRecord]
    ) -> String {
        let dateStr = ISO8601DateFormatter().string(from: dayPlan.date).prefix(10)
        let cal = Calendar.current
        let isWeekend = cal.isDateInWeekend(dayPlan.date)
        let slots = isWeekend ? request.slotConfig.weekend : request.slotConfig.weekday
        let slotStr = slots.map { $0.rawValue }.joined(separator: "・")
        let otherMeals = plan.days
            .filter { $0.id != dayPlan.id }
            .flatMap { $0.meals }
            .compactMap { $0.recipeName }
            .joined(separator: "、")
        let familyText = buildFamilyText(request.familyProfile)
        let recipeLines = recipes.map { r in
            "ID:\(r.id) 名前:\(r.name) 種別:\(r.cuisineType.rawValue) 主材料:\(r.mainIngredient.rawValue) 調理法:\(r.cookingMethod.rawValue) カロリー:\(Int(r.caloriesPerServing))kcal"
        }.joined(separator: "\n")

        return """
        以下の1日分の献立を提案してください。

        【対象日】\(dateStr)（\(slotStr)）
        【家族情報】
        \(familyText)
        【他の日で既に使っているレシピ（重複を避けること）】
        \(otherMeals.isEmpty ? "なし" : otherMeals)
        【選択可能なレシピ一覧】
        \(recipeLines)

        【出力形式】
        {
          "date": "\(dateStr)",
          "meals": {
            "breakfast": {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""},
            "lunch": {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""},
            "dinner": {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""}
          }
        }
        スロット外のキーは省略。説明文は不要。
        """
    }

    private func buildFamilyText(_ profile: FamilyProfile?) -> String {
        guard let profile else { return "- 人数: 1人" }
        let count = profile.members.count
        let ageGroups = profile.members.map { $0.ageGroup.rawValue }.joined(separator: "・")
        let allergies = Set(profile.members.flatMap { $0.allergies }).sorted()
        let dislikes = Set(profile.members.flatMap { $0.dislikes }).sorted()
        return """
        - 人数: \(count)人
        - 年齢層: \(ageGroups)
        - アレルギー: \(allergies.isEmpty ? "なし" : allergies.joined(separator: "、"))（含むレシピは絶対選ばないこと）
        - 苦手な食べ物: \(dislikes.isEmpty ? "なし" : dislikes.joined(separator: "、"))
        """
    }

    private func buildSlotsText(request: GenerationRequest) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return (0..<request.numberOfDays).map { i in
            let date = cal.date(byAdding: .day, value: i, to: request.startDate)!
            let slots = cal.isDateInWeekend(date)
                ? request.slotConfig.weekend.map { $0.rawValue }
                : request.slotConfig.weekday.map { $0.rawValue }
            return "\(fmt.string(from: date)): \(slots.joined(separator: "・"))"
        }.joined(separator: "\n")
    }

    // MARK: - JSON Parsing

    private struct PlanResponse: Decodable {
        let days: [DayResponse]
    }

    private struct DayResponse: Decodable {
        let date: String
        let meals: [String: MealResponse]
    }

    private struct MealResponse: Decodable {
        let recipe_id: String
        let recipe_name: String
        let notes: String
    }

    private func parsePlanJSON(
        _ text: String,
        request: GenerationRequest,
        context: ModelContext
    ) throws -> MealPlan {
        let data = try extractJSON(from: text)
        let response = try JSONDecoder().decode(PlanResponse.self, from: data)

        let endDate = Calendar.current.date(
            byAdding: .day, value: request.numberOfDays - 1, to: request.startDate
        ) ?? request.startDate

        let plan = MealPlan(startDate: request.startDate, endDate: endDate)
        plan.generationConditions = request.conditions
        plan.slotConfigWeekday = request.slotConfig.weekday.map { $0.rawValue }
        plan.slotConfigWeekend = request.slotConfig.weekend.map { $0.rawValue }
        context.insert(plan)

        for dayResp in response.days {
            let date = parseDate(dayResp.date) ?? request.startDate
            let dayPlan = DayPlan(date: date)
            context.insert(dayPlan)
            appendMeals(from: dayResp.meals, to: dayPlan, context: context)
            plan.days.append(dayPlan)
        }
        return plan
    }

    private func parseDayJSON(
        _ text: String,
        into dayPlan: DayPlan,
        context: ModelContext
    ) throws {
        let data = try extractJSON(from: text)
        let dayResp = try JSONDecoder().decode(DayResponse.self, from: data)
        // 既存の食事を削除
        dayPlan.meals.forEach { context.delete($0) }
        dayPlan.meals.removeAll()
        appendMeals(from: dayResp.meals, to: dayPlan, context: context)
    }

    private func appendMeals(
        from mealsDict: [String: MealResponse],
        to dayPlan: DayPlan,
        context: ModelContext
    ) {
        let mealTypeMap: [String: MealType] = [
            "breakfast": .breakfast,
            "lunch": .lunch,
            "dinner": .dinner,
            "snack": .snack
        ]
        for (key, mealResp) in mealsDict {
            guard let mealType = mealTypeMap[key] else { continue }
            let meal = PlannedMeal(mealType: mealType)
            if let recipe = RecipeDatabase.shared.findByID(mealResp.recipe_id) {
                meal.recipeID = recipe.id
                meal.recipeName = recipe.name
                meal.recipeURL = recipe.url.isEmpty ? nil : recipe.url
            } else {
                meal.recipeName = mealResp.recipe_name
            }
            meal.notes = mealResp.notes
            context.insert(meal)
            dayPlan.meals.append(meal)
        }
    }

    private func extractJSON(from text: String) throws -> Data {
        guard let startIdx = text.firstIndex(of: "{"),
              let endIdx = text.lastIndex(of: "}") else {
            throw GenerationError.invalidJSON("JSONが見つかりません")
        }
        let jsonString = String(text[startIdx...endIdx])
        guard let data = jsonString.data(using: .utf8) else {
            throw GenerationError.invalidJSON("エンコードエラー")
        }
        return data
    }

    private func parseDate(_ string: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current
        return fmt.date(from: string)
    }
}
