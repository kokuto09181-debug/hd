import SwiftUI

// MARK: - RecipeSearchView
// レシピDB を検索して PlannedMeal に紐付けるための汎用ピッカー。
// MealSlotEditView・AddMealSheet の両方から使用する。

struct RecipeSearchView: View {
    let onSelect: (RecipeRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [RecipeRecord] {
        RecipeDatabase.shared.searchRecipes(query: query, limit: 40)
    }

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(results, id: \.id) { recipe in
                        Button {
                            onSelect(recipe)
                            dismiss()
                        } label: {
                            RecipeResultRow(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "料理名で検索")
            .navigationTitle("レシピを選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Row

private struct RecipeResultRow: View {
    let recipe: RecipeRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(cuisineEmoji)
                .font(.title2)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(recipe.cuisineType.rawValue)
                    Text("·")
                    Text(recipe.mainIngredient.rawValue)
                    if recipe.caloriesPerServing > 0 {
                        Text("·")
                        Text("\(Int(recipe.caloriesPerServing)) kcal")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if !recipe.url.isEmpty {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var cuisineEmoji: String {
        switch recipe.cuisineType {
        case .japanese: return "🍱"
        case .western:  return "🍝"
        case .chinese:  return "🥟"
        case .ethnic:   return "🍛"
        case .other:    return "🍽️"
        }
    }
}
