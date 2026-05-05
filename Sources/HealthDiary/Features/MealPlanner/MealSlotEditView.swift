import SwiftUI

struct MealSlotEditView: View {
    @Bindable var meal: PlannedMeal
    @Environment(\.dismiss) private var dismiss

    // どのレシピ検索を開いているか: "main" / "side" / "soup"
    @State private var searchTarget: SearchTarget? = nil

    enum SearchTarget: String, Identifiable {
        case main, side, soup
        var id: String { rawValue }
    }

    private var showSideDish: Bool { meal.mealType == .lunch || meal.mealType == .dinner }
    private var showSoup:     Bool { meal.mealType == .dinner }

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
                    // ---- メイン料理 ----
                    Section("メイン料理") {
                        recipeRow(
                            name: meal.recipeName,
                            url: meal.recipeURL,
                            onSearch: { searchTarget = .main },
                            onClear: {
                                meal.recipeID = nil
                                meal.recipeName = nil
                                meal.recipeURL = nil
                            },
                            nameFallback: Binding(
                                get: { meal.recipeName ?? "" },
                                set: { meal.recipeName = $0.isEmpty ? nil : $0 }
                            )
                        )
                    }

                    // ---- 副菜（昼食・夕食） ----
                    if showSideDish {
                        Section("副菜") {
                            recipeRow(
                                name: meal.sideDishName,
                                url: meal.sideDishURL,
                                onSearch: { searchTarget = .side },
                                onClear: {
                                    meal.sideDishID = nil
                                    meal.sideDishName = nil
                                    meal.sideDishURL = nil
                                },
                                nameFallback: Binding(
                                    get: { meal.sideDishName ?? "" },
                                    set: { meal.sideDishName = $0.isEmpty ? nil : $0 }
                                )
                            )
                        }
                    }

                    // ---- 汁物（夕食） ----
                    if showSoup {
                        Section("汁物") {
                            recipeRow(
                                name: meal.soupName,
                                url: meal.soupURL,
                                onSearch: { searchTarget = .soup },
                                onClear: {
                                    meal.soupID = nil
                                    meal.soupName = nil
                                    meal.soupURL = nil
                                },
                                nameFallback: Binding(
                                    get: { meal.soupName ?? "" },
                                    set: { meal.soupName = $0.isEmpty ? nil : $0 }
                                )
                            )
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
            .sheet(item: $searchTarget) { target in
                RecipeSearchView { recipe in
                    switch target {
                    case .main:
                        meal.recipeID   = recipe.id
                        meal.recipeName = recipe.name
                        meal.recipeURL  = recipe.url.isEmpty ? nil : recipe.url
                    case .side:
                        meal.sideDishID   = recipe.id
                        meal.sideDishName = recipe.name
                        meal.sideDishURL  = recipe.url.isEmpty ? nil : recipe.url
                    case .soup:
                        meal.soupID   = recipe.id
                        meal.soupName = recipe.name
                        meal.soupURL  = recipe.url.isEmpty ? nil : recipe.url
                    }
                }
            }
        }
    }

    // MARK: - 共通レシピ行

    @ViewBuilder
    private func recipeRow(
        name: String?,
        url: String?,
        onSearch: @escaping () -> Void,
        onClear: @escaping () -> Void,
        nameFallback: Binding<String>
    ) -> some View {
        if let name {
            HStack(spacing: 12) {
                Text(recipeEmoji(for: name))
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                    if let urlString = url, let recipeURL = URL(string: urlString) {
                        Link("レシピを見る ↗", destination: recipeURL)
                            .font(.caption)
                    }
                }
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            Button(action: onSearch) {
                Label("レシピを変更", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
        } else {
            Button(action: onSearch) {
                Label("DBからレシピを選ぶ", systemImage: "magnifyingglass")
                    .font(.subheadline)
            }

            TextField("または料理名を入力", text: nameFallback)
                .foregroundStyle(.primary)
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
