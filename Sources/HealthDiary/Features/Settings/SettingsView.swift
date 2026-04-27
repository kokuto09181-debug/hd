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
                Label("Apple Intelligence", systemImage: "apple.intelligence")
                Spacer()
                availabilityIcon
            }

            if !llm.availability.isAvailable {
                Text(llm.availability.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } header: {
            Text("AI")
        } footer: {
            Text(availabilityFooter)
        }
    }

    private var availabilityIcon: some View {
        Group {
            switch llm.availability {
            case .available:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .notEnabled, .notReady:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .deviceNotSupported, .requiresOSUpdate:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private var availabilityFooter: String {
        switch llm.availability {
        case .available:
            return "オンデバイスで動作中。会話内容は端末外に送信されません。"
        case .notEnabled:
            return "設定 > Apple IntelligenceとSiri からオンにしてください。"
        case .notReady:
            return "Apple Intelligenceのモデルを準備中です。"
        case .deviceNotSupported:
            return "iPhone 15 Pro以降、またはiPad Pro (M4)以降が必要です。"
        case .requiresOSUpdate:
            return "iOS 18.1以降（日本語はiOS 18.4以降）が必要です。"
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
