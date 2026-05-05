import SwiftUI

// MARK: - Meal Generation Config View（献立スタイル設定）

struct MealGenerationConfigView: View {
    @ObservedObject private var settings = MealGenerationSettings.shared

    var body: some View {
        List {
            overallPresetsSection
            slotSection(title: "朝食（平日）", binding: $settings.config.breakfastWeekday, mealType: .breakfast)
            slotSection(title: "朝食（休日）", binding: $settings.config.breakfastWeekend, mealType: .breakfast)
            slotSection(title: "昼食（平日）", binding: $settings.config.lunchWeekday,     mealType: .lunch)
            slotSection(title: "昼食（休日）", binding: $settings.config.lunchWeekend,     mealType: .lunch)
            slotSection(title: "夕食（平日）", binding: $settings.config.dinnerWeekday,    mealType: .dinner)
            slotSection(title: "夕食（休日）", binding: $settings.config.dinnerWeekend,    mealType: .dinner)
        }
        .navigationTitle("献立スタイル")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Overall Presets

    private var overallPresetsSection: some View {
        Section {
            ForEach(MealGenerationConfig.overallPresets) { preset in
                Button {
                    withAnimation { settings.apply(preset.config) }
                } label: {
                    HStack(spacing: 14) {
                        Text(preset.emoji)
                            .font(.title2)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(presetSummary(preset.config))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if settings.config == preset.config {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("全体プリセット")
        } footer: {
            Text("スロットごとに個別設定も可能です")
        }
    }

    // MARK: - Per-Slot Section

    @ViewBuilder
    private func slotSection(
        title: String,
        binding: Binding<MealSlotTemplate>,
        mealType: MealType
    ) -> some View {
        Section(title) {
            ForEach(MealSlotTemplate.presets(for: mealType)) { template in
                Button {
                    withAnimation { binding.wrappedValue = template }
                } label: {
                    HStack(spacing: 14) {
                        Text(template.emoji)
                            .font(.title3)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(template.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(template.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if binding.wrappedValue == template {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func presetSummary(_ config: MealGenerationConfig) -> String {
        "朝: \(config.breakfastWeekday.emoji)\(config.breakfastWeekday.name) · 昼: \(config.lunchWeekday.emoji)\(config.lunchWeekday.name) · 夕: \(config.dinnerWeekday.emoji)\(config.dinnerWeekday.name)"
    }
}

// MARK: - Compact Style Picker（作成画面埋め込み用）

struct MealStyleInlinePicker: View {
    @ObservedObject private var settings = MealGenerationSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 全体プリセットのクイック選択
            HStack(spacing: 8) {
                ForEach(MealGenerationConfig.overallPresets) { preset in
                    Button {
                        withAnimation { settings.apply(preset.config) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(preset.emoji).font(.title2)
                            Text(preset.name)
                                .font(.caption2)
                                .foregroundStyle(settings.config == preset.config ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            settings.config == preset.config
                                ? Color.accentColor
                                : Color(.systemGray6)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
