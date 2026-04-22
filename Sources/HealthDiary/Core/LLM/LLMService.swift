import Foundation
import MLXLMCommon

// MLX requires real Apple Silicon hardware — exclude macros from simulator
#if !targetEnvironment(simulator)
import MLXLLM
import MLXHuggingFace
import Tokenizers
#endif

@MainActor
final class LLMService: ObservableObject {
    static let shared = LLMService()

    @Published var isLoading = false
    @Published var isModelLoaded = false
    @Published var downloadState: ModelDownloadState = .notLoaded

    #if !targetEnvironment(simulator)
    private var modelContainer: ModelContainer?
    #endif

    private init() {}

    // Load the bundled Gemma 4 model into memory
    func loadModelIfNeeded() async {
        guard !isModelLoaded else { return }
        downloadState = .loading

        #if !targetEnvironment(simulator)
        // Model is bundled in the app — no network needed
        let modelDir = Bundle.main.bundleURL.appendingPathComponent("model")
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            downloadState = .error("同梱モデルが見つかりません")
            return
        }
        do {
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                from: modelDir,
                using: #huggingFaceTokenizerLoader()
            )
            isModelLoaded = true
            downloadState = .ready
        } catch {
            downloadState = .error(error.localizedDescription)
        }
        #else
        downloadState = .error("シミュレーターでは利用不可")
        #endif
    }

    // Called from HealthDiaryApp on launch
    func autoDownloadIfNeeded() async {
        await loadModelIfNeeded()
    }

    func generate(prompt: String, context: LLMContext) async throws -> String {
        #if targetEnvironment(simulator)
        return "シミュレーターではAIモデルを利用できません。実機でお試しください。"
        #else
        guard let container = modelContainer else {
            return "AIモデルがまだ読み込まれていません。しばらくお待ちください。"
        }
        isLoading = true
        defer { isLoading = false }

        let system = buildSystemPrompt(for: context)
        let session = ChatSession(container, instructions: system)
        return try await session.respond(to: prompt)
        #endif
    }

    private func buildSystemPrompt(for context: LLMContext) -> String {
        switch context {
        case .recipe(let name, let ingredients):
            if name.isEmpty {
                return "料理・レシピの相談アシスタントです。日本語で簡潔に答えます。"
            }
            return "料理アシスタントです。\(name)（\(ingredients.joined(separator: "、"))）について日本語で簡潔に答えます。"
        case .mealPlan(let days, let familySize):
            return "\(familySize)人家族の食事・献立相談アシスタントです。\(days)日分を目安に日本語で提案します。"
        case .leftover(let recipeName, let pantryItems):
            let pantryText = pantryItems.isEmpty ? "" : "\n冷蔵庫にある食材: \(pantryItems.joined(separator: "、"))"
            if recipeName.isEmpty {
                return "残り物・冷蔵庫にある食材を使ったレシピを提案する日本語アシスタントです。\(pantryText)"
            }
            return "残り物活用アシスタントです。\(recipeName)を使ったアレンジを日本語で提案します。\(pantryText)"
        case .health:
            return "健康管理・栄養アドバイスの日本語アシスタントです。医療的診断はしません。"
        case .free:
            return "食事・健康管理アプリのアシスタントです。日本語で簡潔に答えます。"
        case .foodAnalysis:
            return "食事の画像認識結果から日本語の料理名と推定カロリーを答えてください。回答形式: 料理名|推定カロリー(kcal)　例: 炒飯|550"
        }
    }

    /// ChatContext を LLMContext に変換する
    static func fromChatContext(
        _ chatContext: ChatContext,
        profile: FamilyProfile?,
        pantryItems: [String] = []
    ) -> LLMContext {
        switch chatContext {
        case .recipe:
            return .recipe(name: "", ingredients: [])
        case .mealPlan:
            return .mealPlan(days: 7, familySize: profile?.members.count ?? 1)
        case .leftover:
            return .leftover(recipeName: "", pantryItems: pantryItems)
        case .health:
            return .health
        case .free:
            return .free
        }
    }
}

enum ModelDownloadState: Equatable {
    case notLoaded
    case loading
    case ready
    case error(String)

    var description: String {
        switch self {
        case .notLoaded:  return "未読み込み"
        case .loading:    return "読み込み中…"
        case .ready:      return "使用可能"
        case .error(let msg): return "エラー: \(msg)"
        }
    }
}

enum LLMContext {
    case recipe(name: String, ingredients: [String])
    case mealPlan(days: Int, familySize: Int)
    case leftover(recipeName: String, pantryItems: [String] = [])
    case health
    case free
    case foodAnalysis
}
