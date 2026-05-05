import SwiftUI
import SwiftData

struct FoodLogView: View {
    @Query(sort: \FoodLogEntry.loggedAt, order: .reverse) private var allEntries: [FoodLogEntry]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var showingCamera = false

    private var todayEntries: [FoodLogEntry] {
        let start = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { $0.loggedAt >= start }
    }

    private var todayCalories: Double {
        todayEntries.reduce(0) { $0 + $1.totalCalories }
    }

    private var groupedEntries: [(MealType, [FoodLogEntry])] {
        let order: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        let grouped = Dictionary(grouping: todayEntries) { $0.mealType }
        return order.compactMap { type in
            guard let entries = grouped[type], !entries.isEmpty else { return nil }
            return (type, entries)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                calorySummarySection

                ForEach(groupedEntries, id: \.0) { mealType, entries in
                    Section(mealType.rawValue) {
                        ForEach(entries) { entry in
                            FoodLogRow(entry: entry)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { context.delete(entries[$0]) }
                        }
                    }
                }

                if todayEntries.isEmpty {
                    ContentUnavailableView(
                        "今日の記録がありません",
                        systemImage: "fork.knife",
                        description: Text("カメラで食事を記録しましょう")
                    )
                }
            }
            .navigationTitle("食事記録")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("写真から記録", systemImage: "camera")
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Label("手動で記録", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                FoodLogAddView()
            }
            // fullScreenCover で提示しないと UIImagePickerController（カメラ）が
            // 最上位のビューコントローラから提示できずシートの中で動作しない
            .fullScreenCover(isPresented: $showingCamera) {
                FoodPhotoCaptureView()
            }
        }
    }

    private var calorySummarySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日の摂取カロリー")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(todayCalories)) kcal")
                        .font(.title.bold())
                        .foregroundStyle(.pink)
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.pink.opacity(0.3))
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Log Row

private struct FoodLogRow: View {
    let entry: FoodLogEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.recipeName)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(sourceLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor.opacity(0.15))
                        .foregroundStyle(sourceColor)
                        .clipShape(Capsule())
                    if entry.servings != 1.0 {
                        Text("×\(String(format: "%.1f", entry.servings))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text("\(Int(entry.totalCalories)) kcal")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var sourceLabel: String {
        switch entry.source {
        case .recipe: return "レシピ"
        case .photo: return "写真"
        case .manual: return "手動"
        }
    }

    private var sourceColor: Color {
        switch entry.source {
        case .recipe: return .teal
        case .photo: return .purple
        case .manual: return .orange
        }
    }
}

// MARK: - Manual Add

struct FoodLogAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MealPlan.startDate, order: .reverse) private var allPlans: [MealPlan]
    private var plans: [MealPlan] { allPlans.filter { $0.status == .shopping } }

    @State private var recipeName = ""
    @State private var calories = ""
    @State private var servings = 1.0
    @State private var mealType: MealType = .dinner
    @State private var selectedMeal: PlannedMeal? = nil

    private var todayMeals: [PlannedMeal] {
        let today = Calendar.current.startOfDay(for: Date())
        return plans.first?.days
            .first { Calendar.current.startOfDay(for: $0.date) == today }?
            .meals ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                if !todayMeals.isEmpty {
                    Section("今日の献立から") {
                        ForEach(todayMeals) { meal in
                            if let name = meal.recipeName {
                                Button {
                                    recipeName = name
                                    mealType = meal.mealType
                                    selectedMeal = meal
                                } label: {
                                    HStack {
                                        Text(meal.mealType.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 36, alignment: .leading)
                                        Text(name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedMeal?.id == meal.id {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("手動入力") {
                    TextField("料理名", text: $recipeName)

                    Picker("食事", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }

                    HStack {
                        Text("カロリー")
                        Spacer()
                        TextField("kcal", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kcal")
                            .foregroundStyle(.secondary)
                    }

                    Stepper(value: $servings, in: 0.5...5.0, step: 0.5) {
                        HStack {
                            Text("人前")
                            Spacer()
                            Text(String(format: "%.1f", servings))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("食事を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(recipeName.isEmpty || (calories.isEmpty && selectedMeal == nil))
                }
            }
        }
    }

    private func save() {
        let kcal = Double(calories) ?? 0
        let entry = FoodLogEntry(
            mealType: mealType,
            recipeName: recipeName,
            caloriesPerServing: kcal,
            servings: servings,
            source: selectedMeal != nil ? .recipe : .manual,
            recipeID: selectedMeal?.recipeID
        )
        context.insert(entry)
        dismiss()
    }
}
