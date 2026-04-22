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
                switch llm.downloadState {
                case .loading:
                    ProgressView()
                        .scaleEffect(0.8)
                case .ready:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                case .notLoaded:
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                }
            }

            if case .error(let msg) = llm.downloadState {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("AIモデル")
        } footer: {
            Text("アプリに同梱されたオンデバイスモデルです。通信不要でプライバシーが守られます。")
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
