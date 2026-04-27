import SwiftUI

struct SettingsView: View {
    @StateObject private var store = StoreService.shared
    @StateObject private var llm = LLMService.shared
    @State private var showingPaywall = false

    var body: some View {
        List {
            familySection
            subscriptionSection
            aiModelSection
            appInfoSection
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    // MARK: - Sections

    private var familySection: some View {
        Section("家族") {
            NavigationLink {
                FamilyProfileView()
            } label: {
                Label("家族の設定", systemImage: "person.2.fill")
            }
        }
    }

    private var subscriptionSection: some View {
        Section("サブスクリプション") {
            if store.isPremium {
                HStack {
                    Label("プレミアム有効", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                    Spacer()
                    Text("有効")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Label("プレミアムにアップグレード", systemImage: "star")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var aiModelSection: some View {
        Section {
            HStack {
                Label("Gemma 4 E2B (4-bit量子化)", systemImage: "brain")
                Spacer()
                modelStateIcon
            }

            // ダウンロード中のプログレスバー
            if case .downloading(let progress) = llm.downloadState {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(.blue)
                    Text("\(Int(progress * 100))% ダウンロード中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // エラー詳細 + 再試行ボタン
            if case .error(let msg) = llm.downloadState {
                VStack(alignment: .leading, spacing: 8) {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("再試行") {
                        Task { await llm.downloadAndLoadIfNeeded() }
                    }
                    .font(.caption)
                }
            }

            // 未ダウンロード時の手動ダウンロードボタン
            if case .notLoaded = llm.downloadState {
                Button {
                    Task { await llm.downloadAndLoadIfNeeded() }
                } label: {
                    Label("今すぐダウンロード（約1.5GB）", systemImage: "arrow.down.circle")
                }
            }

        } header: {
            Text("AIモデル")
        } footer: {
            Text(modelFooterText)
        }
    }

    private var modelStateIcon: some View {
        Group {
            switch llm.downloadState {
            case .notLoaded:
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            case .downloading:
                ProgressView()
                    .scaleEffect(0.8)
            case .loading:
                ProgressView()
                    .scaleEffect(0.8)
            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var modelFooterText: String {
        switch llm.downloadState {
        case .notLoaded:
            return "初回のみWi-Fiでのダウンロードが必要です（約1.5GB）。以降はオフラインで動作し、会話内容は端末外に送信されません。"
        case .downloading:
            return "Wi-Fiでのダウンロードをお勧めします。ダウンロード後はオフラインで動作します。"
        case .loading:
            return "モデルをメモリに読み込んでいます…"
        case .ready:
            return "オンデバイスで動作中。会話内容は端末外に送信されません。"
        case .error:
            return "ダウンロードに失敗しました。Wi-Fi接続を確認してから再試行してください。"
        }
    }

    private var appInfoSection: some View {
        Section("アプリ情報") {
            HStack {
                Text("バージョン")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
