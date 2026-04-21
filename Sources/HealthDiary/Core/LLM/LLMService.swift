import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace

@MainActor
final class LLMService: ObservableObject {
    static let shared = LLMService()

    @Published var isLoading = false
    @Published var isModelLoaded = false
    @Published var downloadProgress: Double = 0
    @Published var downloadState: ModelDownloadState = .notDownloaded

    private var modelContainer: ModelContainer?
    // Gemma 4 E2B 4bit: Google's latest 2B-effective model (~1GB), supports Japanese
    private let modelID = "mlx-community/gemma-4-e2b-it-4bit"
    private let downloadedKey = "llm_model_downloaded"

    private init() {}

    // Called on ChatThreadView.task — silently loads from HF cache if available
    func loadModelIfNeeded() async {
        guard !isModelLoaded else { return }
        guard UserDefaults.standard.bool(forKey: downloadedKey) else { return }
        do {
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: ModelConfiguration(id: modelID)
            )
            isModelLoaded = true
            downloadState = .ready
        } catch {
            downloadState = .notDownloaded
            UserDefaults.standard.removeObject(forKey: downloadedKey)
        }
    }

    // Called from HealthDiaryApp on first launch — downloads in background
    func autoDownloadIfNeeded() async {
        guard !isModelLoaded else { return }
        guard downloadState == .notDownloaded else { return }
        guard !UserDefaults.standard.bool(forKey: downloadedKey) else {
            await loadModelIfNeeded()
            return
        }
        await downloadModel()
    }

    func downloadModel() async {
        guard downloadState != .downloading else { return }
        downloadState = .downloading
        downloadProgress = 0
        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: ModelConfiguration(id: modelID),
                progressHandler: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
            )
            modelContainer = container
            isModelLoaded = true
            downloadState = .ready
            UserDefaults.standard.set(true, forKey: downloadedKey)
        } catch {
            downloadState = .error(error.localizedDescription)
        }
    }

    func generate(prompt: String, context: LLMContext) async throws -> String {
        guard let container = modelContainer else {
            return "AIモデルがまだ読み込まれていません。しばらくお待ちください。"
        }
        isLoading = true
        defer { isLoading = false }

        let system = buildSystemPrompt(for: context)
        let session = ChatSession(container, instructions: system)
        return try await session.respond(to: prompt)
    }

    private func buildSystemPrompt(for context: LLMContext) -> String {
        switch context {
        case .recipe(let name, let ingredients):
            return "料理アシスタントです。\(name)（\(ingredients.joined(separator: "、"))）について日本語で簡潔に答えます。"
        case .mealPlan(let days, let familySize):
            return "\(familySize)人家族\(days)日分の献立提案をする日本語アシスタントです。"
        case .leftover(let recipeName):
            return "残り物活用アシスタントです。\(recipeName)を使ったアレンジを日本語で提案します。"
        case .health:
            return "健康管理アシスタントです。日本語で簡潔に答えます。"
        case .free:
            return "食事・健康管理アプリのアシスタントです。日本語で簡潔に答えます。"
        }
    }
}

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading
    case ready
    case error(String)

    var description: String {
        switch self {
        case .notDownloaded: return "未ダウンロード"
        case .downloading: return "ダウンロード中"
        case .ready: return "使用可能"
        case .error(let msg): return "エラー: \(msg)"
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
