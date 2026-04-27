import Foundation
import SwiftData

/// LLMを使った献立生成サービス
///
/// 【設計方針】
/// LLMの役割: 料理名の生成（条件・家族情報を考慮した自然な提案）
/// Swiftの役割: 生成された料理名をDBレシピに照合（食材・カロリー取得）
///
/// LLMにDBのIDを選ばせない理由:
/// - LLMはID参照が苦手（ハルシネーションが多い）
/// - レシピリストをプロンプトに含めると数千トークン → メモリ不足でクラッシュ
/// - 「料理名を自由に提案する」のはLLMが最も得意なこと
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
        case invalidResponse(String)
        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "AIモデルがまだ読み込まれていません"
            case .invalidResponse(let msg): return "献立の生成に失敗しました: \(msg)"
            }
        }
    }

    // MARK: - Generate Full Plan

    func generate(request: GenerationRequest, context: ModelContext) async throws -> MealPlan {
        let prompt = buildPrompt(request: request)
        let llmCtx = LLMContext.mealPlan(
            days: request.numberOfDays,
            familySize: request.familyProfile?.members.count ?? 1
        )
        let rawText = try await LLMService.shared.generate(prompt: prompt, context: llmCtx)
        return try parsePlanJSON(rawText, request: request, context: context)
    }

    // MARK: - Regenerate Single Day

    func regenerateDay(
        dayPlan: DayPlan,
        plan: MealPlan,
        request: GenerationRequest,
        context: ModelContext
    ) async throws {
        let prompt = buildDayPrompt(dayPlan: dayPlan, plan: plan, request: request)
        let llmCtx = LLMContext.mealPlan(
            days: 1,
            familySize: request.familyProfile?.members.count ?? 1
        )
        let rawText = try await LLMService.shared.generate(prompt: prompt, context: llmCtx)
        try parseDayJSON(rawText, into: dayPlan, context: context)
    }

    // MARK: - Public (MealPlanDetailView の全体再生成用)

    func buildPublicPrompt(request: GenerationRequest) -> String {
        buildPrompt(request: request)
    }

    func applyPlanJSON(
        _ text: String,
        to plan: MealPlan,
        request: GenerationRequest,
        context: ModelContext
    ) throws {
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
    // レシピリストは含めない。LLMには「料理名の提案」だけをさせる。

    private func buildPrompt(request: GenerationRequest) -> String {
        let familyText = buildFamilyText(request.familyProfile)
        let conditionsText = request.conditions.isEmpty
            ? "特になし"
            : request.conditions.joined(separator: "、")
        // 最近の料理名だけ渡す（IDや詳細情報は不要）
        let recentNames = request.recentHistory.prefix(15).compactMap { $0.recipeName }
        let recentText = recentNames.isEmpty ? "なし" : recentNames.joined(separator: "、")
        let slotsText = buildSlotsText(request: request)

        return """
        \(familyText)
        希望条件: \(conditionsText)
        最近食べた料理（できるだけ重複を避けること）: \(recentText)

        食事スロット:
        \(slotsText)

        上記の条件で日本の家庭料理の献立を提案してください。
        JSONのみ出力（説明文・コードブロック記号は不要）:
        {"days":[{"date":"YYYY-MM-DD","meals":{"breakfast":"料理名","lunch":"料理名","dinner":"料理名"}},...]}
        スロット外のキーは省略。
        """
    }

    private func buildDayPrompt(
        dayPlan: DayPlan,
        plan: MealPlan,
        request: GenerationRequest
    ) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let dateStr = fmt.string(from: dayPlan.date)
        let isWeekend = Calendar.current.isDateInWeekend(dayPlan.date)
        let slots = isWeekend ? request.slotConfig.weekend : request.slotConfig.weekday
        let slotStr = slots.map { $0.rawValue }.joined(separator: "・")
        let usedNames = plan.days
            .filter { $0.id != dayPlan.id }
            .flatMap { $0.meals }
            .compactMap { $0.recipeName }
            .joined(separator: "、")
        let familyText = buildFamilyText(request.familyProfile)

        return """
        \(familyText)
        \(dateStr)(\(slotStr))の1日分の献立を提案してください。
        他の日で使った料理（重複不可）: \(usedNames.isEmpty ? "なし" : usedNames)
        JSONのみ出力: {"date":"\(dateStr)","meals":{"breakfast":"料理名","dinner":"料理名"}}
        スロット外のキーは省略。
        """
    }

    private func buildFamilyText(_ profile: FamilyProfile?) -> String {
        guard let profile else { return "家族1人" }
        let count = profile.members.count
        let ageGroups = profile.members.map { $0.ageGroup.rawValue }.joined(separator: "・")
        let allergies = Set(profile.members.flatMap { $0.allergies }).sorted()
        let dislikes = Set(profile.members.flatMap { $0.dislikes }).sorted()
        var parts = ["家族\(count)人(\(ageGroups))"]
        if !allergies.isEmpty {
            parts.append("アレルギー: \(allergies.joined(separator: "・"))（このアレルギーを含む料理は絶対に提案しない）")
        }
        if !dislikes.isEmpty {
            parts.append("苦手な食べ物: \(dislikes.joined(separator: "・"))")
        }
        return parts.joined(separator: "、")
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
    // LLMが返す形式: {"days":[{"date":"YYYY-MM-DD","meals":{"breakfast":"料理名",...}}]}
    // 料理名をDBと照合してレシピIDを付与（マッチしない場合はLLMの料理名をそのまま使用）

    private struct PlanResponse: Decodable {
        let days: [DayResponse]
    }

    private struct DayResponse: Decodable {
        let date: String
        let meals: [String: String]   // "breakfast" -> "料理名"
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
        dayPlan.meals.forEach { context.delete($0) }
        dayPlan.meals.removeAll()
        appendMeals(from: dayResp.meals, to: dayPlan, context: context)
    }

    /// LLMが生成した料理名を PlannedMeal に変換。
    /// DBに近いレシピがあれば紐付け（食材・カロリー利用可能になる）。
    /// なければ料理名だけ保存（ユーザーは後で手動編集できる）。
    private func appendMeals(
        from mealsDict: [String: String],
        to dayPlan: DayPlan,
        context: ModelContext
    ) {
        let mealTypeMap: [String: MealType] = [
            "breakfast": .breakfast,
            "lunch": .lunch,
            "dinner": .dinner,
            "snack": .snack
        ]
        let slotOrder: [String] = ["breakfast", "lunch", "dinner", "snack"]
        for key in slotOrder {
            guard let mealName = mealsDict[key],
                  let mealType = mealTypeMap[key] else { continue }
            let meal = PlannedMeal(mealType: mealType)
            // DBで近いレシピを探してリンク
            if let recipe = RecipeDatabase.shared.searchByName(mealName) {
                meal.recipeID = recipe.id
                meal.recipeName = recipe.name
                meal.recipeURL = recipe.url.isEmpty ? nil : recipe.url
            } else {
                // DBに該当なし → LLMの料理名をそのまま使用
                meal.recipeName = mealName
            }
            meal.notes = ""
            context.insert(meal)
            dayPlan.meals.append(meal)
        }
    }

    // MARK: - Helpers

    private func extractJSON(from text: String) throws -> Data {
        guard let startIdx = text.firstIndex(of: "{"),
              let endIdx = text.lastIndex(of: "}") else {
            throw GenerationError.invalidResponse("JSONが見つかりません（出力: \(text.prefix(80))）")
        }
        let jsonString = String(text[startIdx...endIdx])
        guard let data = jsonString.data(using: .utf8) else {
            throw GenerationError.invalidResponse("エンコードエラー")
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
