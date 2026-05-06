import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            familySection
            mealStyleSection
            appInfoSection
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.large)
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

    private var mealStyleSection: some View {
        Section("献立") {
            NavigationLink {
                MealGenerationConfigView()
            } label: {
                HStack {
                    Label("献立スタイル設定", systemImage: "fork.knife")
                    Spacer()
                    Text(MealGenerationSettings.shared.config.matchingPresetName ?? "カスタム")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
