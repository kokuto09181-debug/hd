import Foundation

// Gemma 4 E2B (MLX Swift) のラッパー
// 現時点はスタブ。MLX Swift統合時にここを実装する
@MainActor
final class LLMService: ObservableObject {
    static let shared = LLMService()

    @Published var isLoading = false
    @Published var isModelLoaded = false

    private init() {}

    func loadModelIfNeeded() async {
        // TODO: MLX Swift で Gemma 4 E2B をロード
        isModelLoaded = true
    }

    func generate(prompt: String, context: LLMContext) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        // TODO: MLX Swift による推論に置き換える
        // 現在はデモ用の固定レスポンス
        try await Task.sleep(for: .seconds(1))
        return demoResponse(for: prompt, context: context)
    }

    private func demoResponse(for prompt: String, context: LLMContext) -> String {
        switch context {
        case .recipe:
            return "このレシピについてお答えします。「\(prompt)」ですね。"
        case .mealPlan:
            return "献立についてのご相談ですね。「\(prompt)」について考えてみましょう。"
        case .leftover:
            return "残り物を使ったアレンジレシピを提案します。"
        case .health:
            return "健康管理についてのアドバイスです。継続的な記録が大切です。"
        case .free:
            return "ご質問にお答えします。「\(prompt)」について、もう少し詳しく教えていただけますか？"
        }
    }
}

enum LLMContext {
    case recipe(name: String, ingredients: [String])
    case mealPlan(days: Int, familySize: Int)
    case leftover(recipeName: String)
    case health
    case free

    var chatContext: ChatContext {
        switch self {
        case .recipe: return .recipe
        case .mealPlan: return .mealPlan
        case .leftover: return .leftover
        case .health: return .health
        case .free: return .free
        }
    }
}
