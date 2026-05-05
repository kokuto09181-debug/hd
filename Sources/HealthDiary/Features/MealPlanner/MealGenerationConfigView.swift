import SwiftUI

// MARK: - Meal Generation Config View（献立スタイル設定）
// Xcode 26 では List { Section { ForEach } } の型推論が Binding<C> を誤選択するため、
// Section を独立した View struct に切り出して List のビルダーコンテキストを分離している。

struct MealGenerationConfigView: View {
    @ObservedObject private var settings = MealGenerationSettings.shared

    var body: some View {
        List {
            OverallPresetsSection(settings: settings)
            SlotSection(title: "朝食（平日）", template: $settings.config.breakfastWeekday, mealType: .breakfast)
            SlotSection(title: "朝食（休日）", template: $settings.config.breakfastWeekend, mealType: .breakfast)
            SlotSection(title: "昼食（平日）", template: $settings.config.lunchWeekday,     mealType: .lunch)
            SlotSection(title: "昼食（休日）", template: $settings.config.lunchWeekend,     mealType: .lunch)
            SlotSection(title: "夕食（平日）", template: $settings.config.dinnerWeekday,    mealType: .dinner)
            SlotSection(title: "夕食（休日）", template: $settings.config.dinnerWeekend,    mealType: .dinner)
        }
        .navigationTitle("献立スタイル")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - 全体プリセットセクション

private struct OverallPresetsSection: View {
    @ObservedObject var settings: MealGenerationSettings

    var body: some View {
        Section {
            ForEach(MealGenerationConfig.overallPresets, id: \.id) { preset in
                OverallPresetRow(preset: preset, isSelected: settings.config == preset.config) {
                    withAnimation { settings.apply(preset.config) }
                }
            }
        } header: {
            Text("全体プリセット")
        } footer: {
            Text("スロットごとに個別設定も可能です")
        }
    }
}

private struct OverallPresetRow: View {
    let preset: MealGenerationConfig.Preset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(preset.emoji)
                    .font(.title2)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(presetSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var presetSummary: String {
        let c = preset.config
        return "朝: \(c.breakfastWeekday.emoji)\(c.breakfastWeekday.name) · 昼: \(c.lunchWeekday.emoji)\(c.lunchWeekday.name) · 夕: \(c.dinnerWeekday.emoji)\(c.dinnerWeekday.name)"
    }
}

// MARK: - スロット別セクション

private struct SlotSection: View {
    let title: String
    @Binding var template: MealSlotTemplate
    let mealType: MealType

    var body: some View {
        Section(title) {
            ForEach(MealSlotTemplate.presets(for: mealType), id: \.name) { preset in
                SlotTemplateRow(preset: preset, isSelected: template == preset) {
                    withAnimation { template = preset }
                }
            }
        }
    }
}

private struct SlotTemplateRow: View {
    let preset: MealSlotTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(preset.emoji)
                    .font(.title3)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(preset.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Style Picker（作成画面埋め込み用）

struct MealStyleInlinePicker: View {
    @ObservedObject private var settings = MealGenerationSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(MealGenerationConfig.overallPresets, id: \.id) { preset in
                    InlinePresetButton(
                        preset: preset,
                        isSelected: settings.config == preset.config
                    ) {
                        withAnimation { settings.apply(preset.config) }
                    }
                }
            }
        }
    }
}

private struct InlinePresetButton: View {
    let preset: MealGenerationConfig.Preset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(preset.emoji).font(.title2)
                Text(preset.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.accentColor
                    : Color(.systemGray6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
