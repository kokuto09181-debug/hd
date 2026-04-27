import Foundation
import MLXLMCommon

// MLX requires real Apple Silicon hardware — exclude from simulator
#if !targetEnvironment(simulator)
import MLXLLM
import MLXHuggingFace
import Tokenizers
import Hub
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

    /// HuggingFace のモデルID（4bitに量子化されたGemma 4 2B）
    private static let modelRepoID = "mlx-community/gemma-4-e2b-it-4bit"

    private init() {}

    // MARK: - Public API

    /// アプリ起動時に呼ぶ。未ダウンロードなら自動でダウンロード→ロードする。
    func autoDownloadIfNeeded() async {
        await downloadAndLoadIfNeeded()
    }

    /// UI から明示的に呼ぶことも可能
    func downloadAndLoadIfNeeded() async {
        guard !isModelLoaded else { return }

        #if targetEnvironment(simulator)
        downloadState = .error("シミュレーターでは利用不可")
        #else
        do {
            // 1. ローカルキャッシュに既にあればダウンロードをスキップ
            if let cachedDir = findCachedModelDir() {
                downloadState = .loading
                try await loadFromDir(cachedDir)
            } else {
                // 2. HuggingFace からダウンロード
                let dir = try await downloadModel()
                downloadState = .loading
                try await loadFromDir(dir)
            }
        } catch {
            downloadState = .error(error.localizedDescription)
        }
        #endif
    }

    func generate(prompt: String, context: LLMContext) async throws -> String {
        #if targetEnvironment(simulator)
        return "シミュレーターではAIモデルを利用できません。実機でお試しください。"
        #else
        guard let container = modelContainer else {
            // モデルがまだなければロードを試みてから生成
            await downloadAndLoadIfNeeded()
            guard let container = modelContainer else {
                return "AIモデルを読み込めませんでした。ネットワーク接続を確認してください。"
            }
            return try await runGeneration(prompt: prompt, context: context, container: container)
        }
        return try await runGeneration(prompt: prompt, context: context, container: container)
        #endif
    }

    // MARK: - Private: Download

    #if !targetEnvironment(simulator)

    /// HuggingFace から端末にモデルをダウンロードする
    private func downloadModel() async throws -> URL {
        downloadState = .downloading(progress: 0)

        let hub = HubApi()
        let repo = Hub.Repo(id: Self.modelRepoID)

        let snapshotDir = try await hub.snapshot(from: repo, matching: [
            "*.safetensors",
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json",
        ]) { [weak self] (progress: Foundation.Progress) in
            Task { @MainActor [weak self] in
                self?.downloadState = .downloading(progress: progress.fractionCompleted)
            }
        }
        return snapshotDir
    }

    /// HuggingFace Hub のキャッシュ（Caches/huggingface/hub/）にモデルがあれば URL を返す
    private func findCachedModelDir() -> URL? {
        // swift-transformers の Hub は iOS の Caches ディレクトリにキャッシュを作る
        // モデルID "org/name" → "models--org--name" というフォルダ名になる
        let cachesDir = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first!
        let dirName = "models--" + Self.modelRepoID.replacingOccurrences(of: "/", with: "--")
        let snapshotsDir = cachesDir
            .appendingPathComponent("huggingface/hub")
            .appendingPathComponent(dirName)
            .appendingPathComponent("snapshots")

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDir, includingPropertiesForKeys: nil
        ) else { return nil }

        // config.json が存在するスナップショットを「ダウンロード済み」と判定
        return snapshots.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("config.json").path)
        }
    }

    // MARK: - Private: Load

    private func loadFromDir(_ dir: URL) async throws {
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            from: dir,
            using: #huggingFaceTokenizerLoader()
        )
        isModelLoaded = true
        downloadState = .ready
    }

    // MARK: - Private: Generate

    private func runGeneration(
        prompt: String,
        context: LLMContext,
        container: ModelContainer
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        let system = buildSystemPrompt(for: context)
        let session = ChatSession(container, instructions: system)
        return try await session.respond(to: prompt)
    }

    #endif

    // MARK: - System Prompts

    private func buildSystemPrompt(for context: LLMContext) -> String {
        switch context {
        case .recipe(let name, let ingredients):
            if name.isEmpty { return "料理・レシピの相談アシスタントです。日本語で簡潔に答えます。" }
            return "料理アシスタントです。\(name)（\(ingredients.joined(separator: "、"))）について日本語で簡潔に答えます。"
        case .mealPlan(let days, let familySize):
            return "\(familySize)人家族の食事・献立相談アシスタントです。\(days)日分を目安に日本語で提案します。"
        case .leftover(let recipeName, let pantryItems):
            let pantryText = pantryItems.isEmpty ? "" : "\n冷蔵庫にある食材: \(pantryItems.joined(separator: "、"))"
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

// MARK: - Download State

enum ModelDownloadState: Equatable {
    case notLoaded
    case downloading(progress: Double)  // 0.0 〜 1.0
    case loading
    case ready
    case error(String)

    var description: String {
        switch self {
        case .notLoaded:               return "未ダウンロード"
        case .downloading(let p):      return "ダウンロード中 \(Int(p * 100))%"
        case .loading:                 return "読み込み中…"
        case .ready:                   return "使用可能"
        case .error(let msg):          return "エラー: \(msg)"
        }
    }

    var isDownloading: Bool {
        if case .downloading = self { return true }
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
