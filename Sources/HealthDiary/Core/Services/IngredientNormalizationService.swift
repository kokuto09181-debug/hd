import Foundation
import SwiftData

/// 食材名の正規化サービス
/// 静的マスターテーブル(JSON) + SwiftDataキャッシュ + LLMフォールバック
final class IngredientNormalizationService {
    static let shared = IngredientNormalizationService()

    /// JSON から読み込んだ静的マッピング  [alias.lowercased(): canonical]
    private var staticTable: [String: String] = [:]

    private init() {
        loadStaticTable()
    }

    // MARK: - Static Table

    private func loadStaticTable() {
        guard let url = Bundle.main.url(forResource: "IngredientNormalization", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(NormalizationFile.self, from: data) else {
            return
        }
        for entry in json.aliases {
            staticTable[entry.alias.lowercased()] = entry.canonical
        }
    }

    // MARK: - Normalize

    /// 食材名を正規化する。
    /// 1. 静的テーブルで完全一致
    /// 2. SwiftDataキャッシュ（LLMが過去に学習した別名）で完全一致
    /// 3. 見つからなければ元の名前をそのまま返す（LLM呼び出しは呼び出し元で判断）
    func normalize(_ raw: String, aliases: [IngredientAlias]) -> String {
        let key = raw.lowercased()

        // 1. 静的テーブル
        if let canonical = staticTable[key] {
            return canonical
        }

        // 2. SwiftData キャッシュ
        if let alias = aliases.first(where: { $0.alias == key }) {
            return alias.canonical
        }

        // 3. 元の名前をそのまま返す
        return raw
    }

    /// LLMが別名を学習した際にSwiftDataへ保存する
    func learnAlias(alias: String, canonical: String, context: ModelContext) {
        let key = alias.lowercased()
        // 既存チェック
        let descriptor = FetchDescriptor<IngredientAlias>(
            predicate: #Predicate { $0.alias == key }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }
        let item = IngredientAlias(alias: alias, canonical: canonical)
        context.insert(item)
    }

    // MARK: - LLM Normalization

    /// LLMを使って食材名を正規化し、結果をキャッシュする
    /// - Returns: 正規化後の名前
    @MainActor
    func normalizeWithLLM(
        _ raw: String,
        aliases: [IngredientAlias],
        modelContext: ModelContext
    ) async -> String {
        // まず静的テーブル / キャッシュで試みる
        let quickResult = normalize(raw, aliases: aliases)
        if quickResult != raw { return quickResult }

        // LLM に問い合わせ
        let prompt = """
        次の食材名を一般的な日本語の正式名称に正規化してください。
        正規化された名前だけを返してください（説明不要）。

        食材名: \(raw)
        """
        guard let canonical = try? await LLMService.shared.generate(
            prompt: prompt,
            context: .free
        ) else { return raw }

        let trimmed = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != raw {
            learnAlias(alias: raw, canonical: trimmed, context: modelContext)
            return trimmed
        }
        return raw
    }

    // MARK: - Batch

    /// 買い出しアイテムの名前リストをまとめて正規化
    func normalizeAll(_ names: [String], aliases: [IngredientAlias]) -> [String: String] {
        var result: [String: String] = [:]
        for name in names {
            result[name] = normalize(name, aliases: aliases)
        }
        return result
    }
}

// MARK: - JSON Models

private struct NormalizationFile: Decodable {
    let aliases: [AliasEntry]
}

private struct AliasEntry: Decodable {
    let alias: String
    let canonical: String
}
