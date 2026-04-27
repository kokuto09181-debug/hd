import Foundation
import FoundationModels

// MARK: - LLMService
// Apple Intelligence (FoundationModels) を使用。
// MLX/HuggingFace による2GBダウンロードを廃止。
// 対応デバイス: iPhone 15 Pro以降 / iPhone 16シリーズ (iOS 18.1+, 日本語はiOS 18.4+)

@MainActor
final class LLMService: ObservableObject {
    static let shared = LLMService()

    @Published var isLoading = false

    /// Apple Intelligence が利用可能かどうか
    var availability: AIAvailability {
        guard #available(iOS 18.1, *) else {
            return .requiresOSUpdate
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .deviceNotSupported
            case .appleIntelligenceNotEnabled:
                return .notEnabled
            default:
                return .notReady
            }
        }
    }

    private init() {}

    // MARK: - Generate

    func generate(prompt: String, context: LLMContext) async throws -> String {
        #if targetEnvironment(simulator)
        return simulatorResponse(for: context)
        #else
        guard #available(iOS 18.1, *) else {
            return availability.message
        }
        guard case .available = SystemLanguageModel.default.availability else {
            return availability.message
        }

        isLoading = true
        defer { isLoading = false }

        let system = buildSystemPrompt(for: context)
        let session = LanguageModelSession(instructions: system)

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            throw error
        }
        #endif
    }

    // MARK: - Simulator Stub

    private func simulatorResponse(for context: LLMContext) -> String {
        switch context {
        case .mealPlan:
            // 献立生成のテスト用ダミーレスポンス
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
            let tomorrow = ISO8601DateFormatter().string(
                from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            ).prefix(10)
            return """
            {"days":[{"date":"\(today)","meals":{"breakfast":"納豆ご飯","dinner":"鶏の唐揚げ"}},{"date":"\(tomorrow)","meals":{"breakfast":"卵焼き","lunch":"うどん","dinner":"肉じゃが"}}]}
            """
        default:
            return "（シミュレーター）Apple Intelligenceのレスポンスが返ります。"
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
            return "健康管理・栄養アドバイスの日本語アシスタントです。医療的診断はしません。"
        case .free:
            return "食事・健康管理アプリのアシスタントです。日本語で簡潔に答えます。"
        case .foodAnalysis:
            return "食事の画像認識結果から日本語の料理名と推定カロリーを答えてください。回答形式: 料理名|推定カロリー(kcal)　例: 炒飯|550"
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

// MARK: - Availability

enum AIAvailability {
    case available
    case deviceNotSupported   // iPhone 15 Pro未満
    case notEnabled           // 設定でApple Intelligenceがオフ
    case notReady             // モデル準備中
    case requiresOSUpdate     // iOS 18.1未満

    var message: String {
        switch self {
        case .available:
            return ""
        case .deviceNotSupported:
            return "Apple Intelligenceに対応していないデバイスです。iPhone 15 Pro以降が必要です。"
        case .notEnabled:
            return "Apple Intelligenceが有効になっていません。設定 > Apple IntelligenceとSiri からオンにしてください。"
        case .notReady:
            return "Apple Intelligenceのモデルを準備中です。しばらく待ってから再度お試しください。"
        case .requiresOSUpdate:
            return "iOS 18.1以降が必要です。設定 > 一般 > ソフトウェアアップデート から更新してください。"
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
}
