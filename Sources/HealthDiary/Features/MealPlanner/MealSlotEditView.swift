import SwiftUI

struct MealSlotEditView: View {
    @Bindable var meal: PlannedMeal
    @Environment(\.dismiss) private var dismiss
    @State private var showingRecipeSearch = false

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
                            HStack(spacing: 12) {
                                Text(recipeEmoji(for: name))
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .font(.headline)
                                    if let urlString = meal.recipeURL, let url = URL(string: urlString) {
                                        Link("レシピを見る ↗", destination: url)
                                            .font(.caption)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)

                            Button {
                                showingRecipeSearch = true
                            } label: {
                                Label("レシピを変更", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                            }
                        } else {
                            Button {
                                showingRecipeSearch = true
                            } label: {
                                Label("DBからレシピを選ぶ", systemImage: "magnifyingglass")
                                    .font(.subheadline)
                            }

                            // DBにないレシピは名前を直接入力
                            TextField("または料理名を入力", text: Binding(
                                get: { meal.recipeName ?? "" },
                                set: { meal.recipeName = $0.isEmpty ? nil : $0 }
                            ))
                            .foregroundStyle(.primary)
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
            .sheet(isPresented: $showingRecipeSearch) {
                RecipeSearchView { recipe in
                    meal.recipeID   = recipe.id
                    meal.recipeName = recipe.name
                    meal.recipeURL  = recipe.url.isEmpty ? nil : recipe.url
                }
            }
        }
    }

    private func recipeEmoji(for name: String) -> String {
        if name.contains("肉") || name.contains("ステーキ") { return "🥩" }
        if name.contains("魚") || name.contains("刺身")    { return "🐟" }
        if name.contains("麺") || name.contains("ラーメン") || name.contains("パスタ") { return "🍜" }
        if name.contains("カレー")   { return "🍛" }
        if name.contains("サラダ")   { return "🥗" }
        if name.contains("スープ") || name.contains("汁") { return "🍲" }
        if name.contains("丼") || name.contains("ご飯")   { return "🍚" }
        if name.contains("パン")     { return "🍞" }
        if name.contains("卵") || name.contains("オムレツ") { return "🍳" }
        return "🍽️"
    }
}
