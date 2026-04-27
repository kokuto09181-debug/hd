import Foundation
import SwiftData
// FoundationModels は Xcode 26 / iOS 26 以降でのみ利用可能。
// Xcode 16.x (macos-15 CI) でもコンパイルできるよう canImport で条件分岐。
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 構造化出力型
// Xcode 26 以降では @Generable + @Guide で型安全な生成。
// Xcode 16.x (CI) では同名の素の struct を定義してコンパイルを通す。

#if canImport(FoundationModels)
@Generable
struct MealPlanOutput {
    @Guide(description: "生成した日数分の献立リスト（指定日数と同じ要素数）")
    var days: [DayMealOutput]
}

@Generable
struct DayMealOutput {
    @Guide(description: "日付 YYYY-MM-DD形式")
    var date: String
    @Guide(description: "朝食の料理名。このスロットを使わない日はnil")
    var breakfast: String?
    @Guide(description: "昼食の料理名。このスロットを使わない日はnil")
    var lunch: String?
    @Guide(description: "夕食の料理名。このスロットを使わない日はnil")
    var dinner: String?
    @Guide(description: "間食の料理名。このスロットを使わない日はnil")
    var snack: String?
}

#else
// Xcode 16.x / FoundationModels 非対応環境向けスタブ型
// CI ビルドおよびシミュレータービルドで同じ型を参照できるようにする

struct MealPlanOutput {
    var days: [DayMealOutput]
    init(days: [DayMealOutput]) { self.days = days }
}

struct DayMealOutput {
    var date: String
    var breakfast: String?
    var lunch: String?
    var dinner: String?
    var snack: String?
    init(
        date: String,
        breakfast: String? = nil,
        lunch: String? = nil,
        dinner: String? = nil,
        snack: String? = nil
    ) {
        self.date = date
        self.breakfast = breakfast
        self.lunch = lunch
        self.dinner = dinner
        self.snack = snack
    }
}
#endif

// MARK: - LLMPlanGenerator

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
        case invalidResponse(String)
        var errorDescription: String? {
            switch self {
            case .invalidResponse(let msg): return "献立の生成に失敗しました: \(msg)"
            }
        }
    }

    // MARK: - Generate Full Plan（新規作成）

    func generate(request: GenerationRequest, context: ModelContext) async throws -> MealPlan {
        let output = try await fetchOutput(for: request)
        return buildPlan(from: output, request: request, context: context)
    }

    // MARK: - Regenerate Full Plan（既存プランの全日置き換え）
    // MealPlannerView から呼ぶ。日の削除は呼び出し元で行う。

    func regenerate(
        plan: MealPlan,
        request: GenerationRequest,
        context: ModelContext
    ) async throws {
        let output = try await fetchOutput(for: request)
        for dayOutput in output.days {
            let date = parseDate(dayOutput.date) ?? request.startDate
            let dayPlan = DayPlan(date: date)
            context.insert(dayPlan)
            appendMeals(from: dayOutput, to: dayPlan, context: context)
            plan.days.append(dayPlan)
        }
    }

    // MARK: - Regenerate Single Day

    func regenerateDay(
        dayPlan: DayPlan,
        plan: MealPlan,
        request: GenerationRequest,
        context: ModelContext
    ) async throws {
        let output = try await fetchDayOutput(for: dayPlan, plan: plan, request: request)
        dayPlan.meals.forEach { context.delete($0) }
        dayPlan.meals.removeAll()
        appendMeals(from: output, to: dayPlan, context: context)
    }

    // MARK: - Private: LLM / Simulator / Fallback 分岐

    private func fetchOutput(for request: GenerationRequest) async throws -> MealPlanOutput {
        #if targetEnvironment(simulator)
        // シミュレーター: スタブデータを返す
        return buildSimulatorOutput(request: request)
        #elseif canImport(FoundationModels)
        // 実機 + Xcode 26 以降: Apple Intelligence で型安全生成
        let prompt = buildPrompt(request: request)
        let llmCtx = LLMContext.mealPlan(
            days: request.numberOfDays,
            familySize: request.familyProfile?.members.count ?? 1
        )
        return try await LLMService.shared.generate(
            prompt: prompt, context: llmCtx, generating: MealPlanOutput.self
        )
        #else
        // Xcode 16.x (CI デバイスビルド): スタブデータで代替
        return buildSimulatorOutput(request: request)
        #endif
    }

    private func fetchDayOutput(
        for dayPlan: DayPlan,
        plan: MealPlan,
        request: GenerationRequest
    ) async throws -> DayMealOutput {
        #if targetEnvironment(simulator)
        return buildSimulatorDayOutput(for: dayPlan.date)
        #elseif canImport(FoundationModels)
        let prompt = buildDayPrompt(dayPlan: dayPlan, plan: plan, request: request)
        let llmCtx = LLMContext.mealPlan(
            days: 1,
            familySize: request.familyProfile?.members.count ?? 1
        )
        return try await LLMService.shared.generate(
            prompt: prompt, context: llmCtx, generating: DayMealOutput.self
        )
        #else
        return buildSimulatorDayOutput(for: dayPlan.date)
        #endif
    }

    // MARK: - Plan Construction

    private func buildPlan(
        from output: MealPlanOutput,
        request: GenerationRequest,
        context: ModelContext
    ) -> MealPlan {
        let endDate = Calendar.current.date(
            byAdding: .day, value: request.numberOfDays - 1, to: request.startDate
        ) ?? request.startDate

        let plan = MealPlan(startDate: request.startDate, endDate: endDate)
        plan.generationConditions = request.conditions
        plan.slotConfigWeekday = request.slotConfig.weekday.map { $0.rawValue }
        plan.slotConfigWeekend = request.slotConfig.weekend.map { $0.rawValue }
        context.insert(plan)

        for dayOutput in output.days {
            let date = parseDate(dayOutput.date) ?? request.startDate
            let dayPlan = DayPlan(date: date)
            context.insert(dayPlan)
            appendMeals(from: dayOutput, to: dayPlan, context: context)
            plan.days.append(dayPlan)
        }
        return plan
    }

    // MARK: - Meal Attachment
    // LLMが生成した料理名を PlannedMeal に変換。
    // DBに近いレシピがあれば紐付け（食材・カロリー利用可能になる）。
    // なければ料理名だけ保存（ユーザーは後で手動編集できる）。

    private func appendMeals(
        from output: DayMealOutput,
        to dayPlan: DayPlan,
        context: ModelContext
    ) {
        let slots: [(MealType, String?)] = [
            (.breakfast, output.breakfast),
            (.lunch,     output.lunch),
            (.dinner,    output.dinner),
            (.snack,     output.snack)
        ]
        for (mealType, mealName) in slots {
            guard let mealName else { continue }
            let meal = PlannedMeal(mealType: mealType)
            if let recipe = RecipeDatabase.shared.searchByName(mealName) {
                meal.recipeID   = recipe.id
                meal.recipeName = recipe.name
                meal.recipeURL  = recipe.url.isEmpty ? nil : recipe.url
            } else {
                // DBに該当なし → LLMの料理名をそのまま使用
                meal.recipeName = mealName
            }
            meal.notes = ""
            context.insert(meal)
            dayPlan.meals.append(meal)
        }
    }

    // MARK: - Prompt Building
    // レシピリストは含めない。LLMには「料理名の提案」だけをさせる。

    private func buildPrompt(request: GenerationRequest) -> String {
        let familyText = buildFamilyText(request.familyProfile)
        let conditionsText = request.conditions.isEmpty
            ? "特になし"
            : request.conditions.joined(separator: "、")
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
        スロット一覧にないスロット（例: スロットがない日の朝食）はnilにしてください。
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
        \(dateStr)（スロット: \(slotStr)）の1日分の献立を提案してください。
        他の日で使った料理（重複不可）: \(usedNames.isEmpty ? "なし" : usedNames)
        スロット外の食事はnilにしてください。
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

    // MARK: - Simulator / Fallback Stubs

    private func buildSimulatorOutput(request: GenerationRequest) -> MealPlanOutput {
        let cal = Calendar.current
        let days = (0..<request.numberOfDays).map { i in
            let date = cal.date(byAdding: .day, value: i, to: request.startDate)!
            return buildSimulatorDayOutput(for: date)
        }
        return MealPlanOutput(days: days)
    }

    private func buildSimulatorDayOutput(for date: Date) -> DayMealOutput {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        // 曜日ごとに異なる献立を返す（バリエーション確認用）
        let menus: [(String?, String?, String?)] = [
            ("納豆ご飯",   nil,           "鶏の唐揚げ"),
            ("卵焼き",     "うどん",      "肉じゃが"),
            ("トースト",   "チャーハン",  "鮭の塩焼き"),
            ("ヨーグルト", nil,           "豚の生姜焼き"),
            ("おにぎり",   "そば",        "野菜炒め"),
            ("パンケーキ", "カレーライス","麻婆豆腐"),
            ("シリアル",   nil,           "ハンバーグ"),
        ]
        let idx = Calendar.current.component(.weekday, from: date) % menus.count
        let (b, l, d) = menus[idx]
        return DayMealOutput(date: fmt.string(from: date), breakfast: b, lunch: l, dinner: d, snack: nil)
    }

    // MARK: - Helpers

    private func parseDate(_ string: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current
        return fmt.date(from: string)
    }
}
