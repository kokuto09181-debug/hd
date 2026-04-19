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

                Section("オプション") {
                    Picker("", selection: $meal.mealOption) {
                        ForEach([MealOption.homeCooked, .diningOut, .skipped], id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if meal.mealOption == .homeCooked {
                    Section("レシピ") {
                        if let name = meal.recipeName {
                            HStack {
                                Text(name)
                                Spacer()
                                if let urlString = meal.recipeURL, let url = URL(string: urlString) {
                                    Link("レシピを見る", destination: url)
                                        .font(.caption)
                                }
                            }
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
}
