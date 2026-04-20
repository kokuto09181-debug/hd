import SwiftUI

struct MealSlotEditView: View {
    @Bindable var meal: PlannedMeal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("食事の種類") {
                    Picker("種類", selection: $meal.mealType) {
                        ForEach(MealType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // スキップを他オプションと分離（ランダム対象外）
                Section("オプション") {
                    Picker("", selection: $meal.mealOption) {
                        Text(MealOption.homeCooked.rawValue).tag(MealOption.homeCooked)
                        Text(MealOption.diningOut.rawValue).tag(MealOption.diningOut)
                    }
                    .pickerStyle(.segmented)

                    Toggle("この食事をスキップ", isOn: Binding(
                        get: { meal.mealOption == .skipped },
                        set: { meal.mealOption = $0 ? .skipped : .homeCooked }
                    ))
                }

                if meal.mealOption == .homeCooked {
                    Section("レシピ") {
                        if let name = meal.recipeName {
                            VStack(alignment: .leading, spacing: 8) {
                                // ビジュアル - 料理系統アイコン
                                HStack(spacing: 12) {
                                    recipeIcon
                                        .font(.system(size: 40))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(name)
                                            .font(.headline)
                                        if let urlString = meal.recipeURL, let url = URL(string: urlString) {
                                            Link("レシピを見る", destination: url)
                                                .font(.caption)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            Text("レシピ未設定")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("メモ") {
                    TextField("メモ（任意）", text: $meal.notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle(meal.mealType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    // レシピ名から推測してアイコン表示（仮ビジュアル）
    private var recipeIcon: some View {
        let name = meal.recipeName ?? ""
        let (emoji, color): (String, Color) = {
            if name.contains("肉") || name.contains("ステーキ") || name.contains("焼肉") { return ("🥩", .red) }
            if name.contains("魚") || name.contains("刺身") || name.contains("寿司") { return ("🐟", .blue) }
            if name.contains("麺") || name.contains("パスタ") || name.contains("ラーメン") { return ("🍜", .orange) }
            if name.contains("カレー") { return ("🍛", .yellow) }
            if name.contains("サラダ") { return ("🥗", .green) }
            if name.contains("スープ") || name.contains("汁") { return ("🍲", .brown) }
            if name.contains("丼") || name.contains("ご飯") { return ("🍚", .pink) }
            if name.contains("パン") { return ("🍞", .yellow) }
            if name.contains("卵") || name.contains("オムレツ") { return ("🍳", .yellow) }
            return ("🍽️", .gray)
        }()
        return Text(emoji).foregroundStyle(color)
    }
}
