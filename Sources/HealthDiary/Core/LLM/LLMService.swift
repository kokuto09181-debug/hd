import Foundation
import FoundationModels

// MARK: - LLMService
// Apple Intelligence (FoundationModels) を使用。
// デプロイターゲット iOS 26.0 のため #available ガード不要。
//
// 2つの生成メソッド:
//   generate(prompt:context:)            → 文字列出力（汎用）
//   generate(prompt:context:generating:) → 型安全な構造化出力 (@Generable)

@MainActor
final class LLMService: ObservableObject {
    static let shared = LLMService()

    @Published var isLoading = false

    var availability: AIAvailability {
        #if targetEnvironment(simulator)
        return .available
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

    // MARK: - 1. 文字列出力

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
        }
    }

    // MARK: - System Prompts

    func buildSystemPrompt(for context: LLMContext) -> String {
        switch context {
        case .mealPlan(let days, let familySize):
            return "\(familySize)人家族の食事・献立相談アシスタントです。\(days)日分を目安に日本語で提案します。"
        case .shoppingConsolidation(let familySize):
            return "\(familySize)人家族の買い物リスト整理アシスタントです。同じ食材を単位を考慮してまとめ、量を正確に計算します。"
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
    case mealPlan(days: Int, familySize: Int)
    case shoppingConsolidation(familySize: Int)
}
