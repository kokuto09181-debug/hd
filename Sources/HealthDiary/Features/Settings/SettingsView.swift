import SwiftUI

struct SettingsView: View {
    @StateObject private var store = StoreService.shared
    @StateObject private var llm = LLMService.shared
    @State private var showingPaywall = false
    @State private var isDownloading = false

    // AIモデルは全ユーザー無料。初回起動時に自動ダウンロード開始。
    private var canUseAI: Bool { true }

    var body: some View {
        List {
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Qwen 2.5 1.5B (4-bit量子化)")
                    Spacer()
                    Text(llm.downloadState.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if llm.downloadState == .downloading {
                    ProgressView(value: llm.downloadProgress)
                        .tint(Color.accentColor)
                    Text("\(Int(llm.downloadProgress * 100))% ダウンロード中…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if llm.downloadState != .ready {
                    if canUseAI {
                        Button {
                            Task {
                                isDownloading = true
                                await llm.downloadModel()
                                isDownloading = false
                            }
                        } label: {
                            Label("AIモデルをダウンロード", systemImage: "arrow.down.circle")
                                .font(.subheadline)
                        }
                        .disabled(isDownloading)
                        Text("約1GB · Wi-Fi推奨")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            Text("プレミアム限定機能です")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("AIモデル")
        } footer: {
            Text("オンデバイスで動作するため、一度ダウンロードすれば通信不要。プライバシーが守られます。")
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
