import Foundation
import FoundationModels

// MARK: - LLMService
// Apple Intelligence (FoundationModels) を使用。
// デプロイターゲット iOS 26.0 のため #available ガード不要。
//
// 3つの生成メソッド:
//   generate(prompt:context:)          → 文字列出力（汎用）
//   generate(prompt:context:generating:) → 型安全な構造化出力 (@Generable)
//   chat(prompt:threadID:context:)     → 会話継続（スレッドごとにセッション保持）

@MainActor
final class LLMService: ObservableObject {
    static let shared = LLMService()

    @Published var isLoading = false

    // チャットスレッドごとの会話セッション（アプリ起動中は保持）
    private var chatSessions: [UUID: LanguageModelSession] = [:]

    var availability: AIAvailability {
        #if targetEnvironment(simulator)
        return .available   // シミュレーターはスタブで対応
        #else
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:           return .deviceNotSupported
            case .appleIntelligenceNotEnabled: return .notEnabled
            default:                           return .notReady
            }
        }
        #endif
    }

    private init() {}

    // MARK: - 1. 文字列出力（汎用・後方互換）

    func generate(prompt: String, context: LLMContext) async throws -> String {
        #if targetEnvironment(simulator)
        return simulatorResponse(for: context)
        #else
        guard availability.isAvailable else { return availability.message }
        isLoading = true
        defer { isLoading = false }
        let session = LanguageModelSession(instructions: buildSystemPrompt(for: context))
        let response = try await session.respond(to: prompt)
        return response.content
        #endif
    }

    // MARK: - 2. 型安全な構造化出力 (@Generable)
    // LLMPlanGenerator で献立を型安全に生成するために使用。
    // JSONパースが不要になり、出力形式の崩れによるクラッシュがなくなる。

    func generate<T: Generable>(
        prompt: String,
        context: LLMContext,
        generating type: T.Type
    ) async throws -> T {
        #if targetEnvironment(simulator)
        throw LLMError.simulatorUnsupported
        #else
        guard availability.isAvailable else {
            throw LLMError.notAvailable(availability.message)
        }
        isLoading = true
        defer { isLoading = false }
        let session = LanguageModelSession(instructions: buildSystemPrompt(for: context))
        let response = try await session.respond(to: prompt, generating: type)
        return response.content
        #endif
    }

    // MARK: - 3. 会話継続チャット（スレッドごとにセッションを保持）
    // 同じ threadID で呼ぶたびに同一セッションを使い、
    // モデルが前の発言を踏まえた返答ができる。

    func chat(
        prompt: String,
        threadID: UUID,
        context: LLMContext
    ) async throws -> String {
        #if targetEnvironment(simulator)
        return "（シミュレーター）\(prompt.prefix(20))... に対するAIの返答です。"
        #else
        guard availability.isAvailable else { return availability.message }
        isLoading = true
        defer { isLoading = false }

        // セッションを取得、なければ新規作成
        let session: LanguageModelSession
        if let existing = chatSessions[threadID] {
            session = existing
        } else {
            let s = LanguageModelSession(instructions: buildSystemPrompt(for: context))
            chatSessions[threadID] = s
            session = s
        }

        let response = try await session.respond(to: prompt)
        return response.content
        #endif
    }

    /// チャットスレッド削除時に呼ぶ。セッションを解放してメモリを回収する。
    func clearChatSession(for threadID: UUID) {
        chatSessions.removeValue(forKey: threadID)
    }

    // MARK: - Simulator Stub

    private func simulatorResponse(for context: LLMContext) -> String {
        switch context {
        case .mealPlan:
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let d0 = fmt.string(from: Date())
            let d1 = fmt.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
            return """
            {"days":[
              {"date":"\(d0)","breakfast":"納豆ご飯","dinner":"鶏の唐揚げ"},
              {"date":"\(d1)","breakfast":"卵焼き","lunch":"うどん","dinner":"肉じゃが"}
            ]}
            """
        case .shoppingConsolidation:
            return "（シミュレーター）買い物リストの整理結果がここに表示されます。"
        default:
            return "（シミュレーター）Apple Intelligenceの返答がここに表示されます。"
        }
    }

    // MARK: - System Prompts

    func buildSystemPrompt(for context: LLMContext) -> String {
        switch context {
        case .recipe(let name, let ingredients):
            if name.isEmpty { return "料理・レシピの相談アシスタントです。日本語で簡潔に答えます。" }
            return "料理アシスタントです。\(name)（\(ingredients.joined(separator: "、"))）について日本語で簡潔に答えます。"
        case .mealPlan(let days, let familySize):
            return "\(familySize)人家族の食事・献立相談アシスタントです。\(days)日分を目安に日本語で提案します。"
        case .leftover(let recipeName, let pantryItems):
            let pantryText = pantryItems.isEmpty ? "" : "冷蔵庫にある食材: \(pantryItems.joined(separator: "、"))"
            if recipeName.isEmpty { return "残り物・冷蔵庫にある食材を使ったレシピを提案する日本語アシスタントです。\(pantryText)" }
            return "残り物活用アシスタントです。\(recipeName)を使ったアレンジを日本語で提案します。\(pantryText)"
        case .health:
            return "健康管理・栄養の情報を提供する日本語アシスタントです。医療的診断はしません。"
        case .free:
            return "食事・健康管理アプリのアシスタントです。日本語で簡潔に答えます。"
        case .foodAnalysis:
            return "食事の画像認識結果から日本語の料理名と推定カロリーを答えてください。回答形式: 料理名|推定カロリー(kcal)　例: 炒飯|550"
        case .shoppingConsolidation(let familySize):
            return "\(familySize)人家族の買い物リスト整理アシスタントです。同じ食材を単位を考慮してまとめ、量を正確に計算します。"
        }
    }

    // MARK: - Context Conversion

    static func fromChatContext(
        _ chatContext: ChatContext,
        profile: FamilyProfile?,
        pantryItems: [String] = []
    ) -> LLMContext {
        switch chatContext {
        case .recipe:   return .recipe(name: "", ingredients: [])
        case .mealPlan: return .mealPlan(days: 7, familySize: profile?.members.count ?? 1)
        case .leftover: return .leftover(recipeName: "", pantryItems: pantryItems)
        case .health:   return .health
        case .free:     return .free
        }
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case notAvailable(String)
    case simulatorUnsupported

    var errorDescription: String? {
        switch self {
        case .notAvailable(let msg): return msg
        case .simulatorUnsupported:  return "シミュレーターでは構造化出力を利用できません"
        }
    }
}

// MARK: - Availability

enum AIAvailability {
    case available
    case deviceNotSupported
    case notEnabled
    case notReady
    case requiresOSUpdate

    var message: String {
        switch self {
        case .available:          return ""
        case .deviceNotSupported: return "Apple Intelligenceに対応していないデバイスです。iPhone 15 Pro以降が必要です。"
        case .notEnabled:         return "Apple Intelligenceが有効になっていません。設定 > Apple IntelligenceとSiri からオンにしてください。"
        case .notReady:           return "Apple Intelligenceのモデルを準備中です。しばらくお待ちください。"
        case .requiresOSUpdate:   return "iOS 26以降が必要です。"
        }
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

// MARK: - LLM Context

enum LLMContext {
    case recipe(name: String, ingredients: [String])
    case mealPlan(days: Int, familySize: Int)
    case leftover(recipeName: String, pantryItems: [String] = [])
    case health
    case free
    case foodAnalysis
    case shoppingConsolidation(familySize: Int)
}
