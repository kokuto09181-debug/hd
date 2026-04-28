import SwiftUI
import SwiftData

// MARK: - MealPlannerView（メイン）

struct MealPlannerView: View {
    @Query(sort: \MealPlan.startDate, order: .reverse) private var allPlans: [MealPlan]
    @Environment(\.modelContext) private var context
    @State private var showingCreation = false

    private var activePlan: MealPlan? {
        let today = Calendar.current.startOfDay(for: Date())
        return allPlans.first {
            $0.status == .shopping &&
            Calendar.current.startOfDay(for: $0.startDate) <= today &&
            Calendar.current.startOfDay(for: $0.endDate) >= today
        }
    }

    private var draftPlans: [MealPlan] {
        allPlans.filter { $0.status == .draft && !$0.isCompleted }
    }

    private var pastPlans: [MealPlan] {
        allPlans.filter { $0.isCompleted }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allPlans.isEmpty {
                    EmptyMealPlanView { showingCreation = true }
                } else {
                    planList
                }
            }
            .navigationTitle("献立")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreation = true
                    } label: {
                        Label("新しい献立を作る", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreation) {
                MealPlanCreationView()
            }
        }
    }

    private var planList: some View {
        List {
            if let active = activePlan {
                Section("実行中") {
                    NavigationLink { MealPlanDetailView(plan: active) } label: {
                        PlanRow(plan: active)
                    }
                }
            }

            if !draftPlans.isEmpty {
                Section("下書き") {
                    ForEach(draftPlans) { plan in
                        NavigationLink { MealPlanDetailView(plan: plan) } label: {
                            PlanRow(plan: plan)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { context.delete(draftPlans[$0]) }
                    }
                }
            }

            if !pastPlans.isEmpty {
                Section("過去の献立") {
                    ForEach(pastPlans) { plan in
                        NavigationLink { MealPlanDetailView(plan: plan) } label: {
                            PlanRow(plan: plan)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

private struct EmptyMealPlanView: View {
    let onCreate: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("献立がありません")
                    .font(.title2.bold())
                Text("AIが家族の好みに合わせた\n複数日の献立を提案します")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: onCreate) {
                Text("献立を作る")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Plan Row

private struct PlanRow: View {
    let plan: MealPlan
    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return "\(fmt.string(from: plan.startDate))〜\(fmt.string(from: plan.endDate))  ·  \(plan.days.count)日間"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateRangeText)
                .font(.body)
            HStack(spacing: 6) {
                statusBadge
                if !plan.generationConditions.isEmpty {
                    Text(plan.generationConditions.prefix(2).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
    private var statusBadge: some View {
        Text(plan.status == .shopping ? "確定済み" : "下書き")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(plan.status == .shopping ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(plan.status == .shopping ? .green : .orange)
            .clipShape(Capsule())
    }
}

// MARK: - Plan Detail

struct MealPlanDetailView: View {
    @Bindable var plan: MealPlan
    @Environment(\.modelContext) private var context
    @Query private var profiles: [FamilyProfile]
    @Query private var history: [MealHistoryEntry]
    @State private var selectedDayIndex = 0
    @State private var isRegenerating = false
    @State private var regenerationError: String? = nil
    @State private var showingShoppingConfirm = false
    @State private var showingRegenerateConfirm = false

    private var sortedDays: [DayPlan] {
        plan.days.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            daySelector
            Divider()
            if isRegenerating {
                regeneratingOverlay
            } else {
                if sortedDays.indices.contains(selectedDayIndex) {
                    DayPlanView(
                        dayPlan: sortedDays[selectedDayIndex],
                        plan: plan,
                        onRegenerateDay: { Task { await regenerateDay(sortedDays[selectedDayIndex]) } }
                    )
                }
            }

            // 下書きのときだけ「確定して開始」ボタンを表示
            if plan.status == .draft && !isRegenerating {
                confirmBar
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog("この献立を確定しますか？\n確定後は買い出しリストが使えるようになります",
                            isPresented: $showingShoppingConfirm,
                            titleVisibility: .visible) {
            Button("献立を確定する") { plan.status = .shopping }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog("この献立を全部作り直しますか？",
                            isPresented: $showingRegenerateConfirm,
                            titleVisibility: .visible) {
            Button("同じ条件で再生成", role: .destructive) { Task { await regenerateAll() } }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("再生成エラー", isPresented: Binding(
            get: { regenerationError != nil },
            set: { if !$0 { regenerationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(regenerationError ?? "")
        }
        .gesture(swipeGesture)
    }

    // MARK: - 確定バー（下書き時に底部表示）

    private var confirmBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showingShoppingConfirm = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                    Text("この献立を確定する")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
            }
        }
        .background(Color(.systemBackground))
    }

    private var navigationTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return "\(fmt.string(from: plan.startDate))〜\(fmt.string(from: plan.endDate))"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if plan.status == .draft {
                    Button {
                        showingRegenerateConfirm = true
                    } label: {
                        Label("全体を再生成", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        showingShoppingConfirm = true
                    } label: {
                        Label("献立を確定する", systemImage: "checkmark.seal")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sortedDays.enumerated()), id: \.element.id) { index, day in
                    DayTab(date: day.date, isSelected: index == selectedDayIndex, isPast: day.isPast) {
                        selectedDayIndex = index
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private var regeneratingOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("再生成中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                if value.translation.width < -40, selectedDayIndex < sortedDays.count - 1 {
                    withAnimation { selectedDayIndex += 1 }
                } else if value.translation.width > 40, selectedDayIndex > 0 {
                    withAnimation { selectedDayIndex -= 1 }
                }
            }
    }

    private func makeRequest() -> LLMPlanGenerator.GenerationRequest {
        LLMPlanGenerator.GenerationRequest(
            numberOfDays: plan.days.count,
            startDate: plan.startDate,
            slotConfig: SlotConfig(
                weekday: plan.slotConfigWeekday.compactMap { MealType(rawValue: $0) },
                weekend: plan.slotConfigWeekend.compactMap { MealType(rawValue: $0) }
            ),
            familyProfile: profiles.first,
            recentHistory: history,
            conditions: plan.generationConditions
        )
    }

    private func regenerateAll() async {
        isRegenerating = true
        regenerationError = nil
        plan.days.forEach { context.delete($0) }
        plan.days.removeAll()
        do {
            let request = makeRequest()
            try await LLMPlanGenerator.shared.regenerate(plan: plan, request: request, context: context)
        } catch {
            regenerationError = error.localizedDescription
        }
        isRegenerating = false
    }

    private func regenerateDay(_ dayPlan: DayPlan) async {
        isRegenerating = true
        regenerationError = nil
        do {
            let request = makeRequest()
            try await LLMPlanGenerator.shared.regenerateDay(
                dayPlan: dayPlan, plan: plan, request: request, context: context
            )
        } catch {
            regenerationError = error.localizedDescription
        }
        isRegenerating = false
    }
}

// MARK: - Day Tab

private struct DayTab: View {
    let date: Date
    let isSelected: Bool
    let isPast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                Text(date, format: .dateTime.day())
                    .font(.headline)
            }
            .frame(width: 44, height: 52)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(
                isSelected
                    ? AnyShapeStyle(.white)
                    : (isPast ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Plan View

struct DayPlanView: View {
    @Bindable var dayPlan: DayPlan
    let plan: MealPlan
    let onRegenerateDay: () -> Void
    @Environment(\.modelContext) private var context
    @State private var mealToEdit: PlannedMeal? = nil
    @State private var showingAddMeal = false

    /// 食事時間ごとにグループ化
    private var mealsByType: [(MealType, [PlannedMeal])] {
        let order: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        let dict = Dictionary(grouping: dayPlan.meals) { $0.mealType }
        return order.compactMap { type in
            guard let meals = dict[type], !meals.isEmpty else { return nil }
            return (type, meals)
        }
    }

    private var canEdit: Bool {
        plan.status == .draft && !dayPlan.isPast
    }

    var body: some View {
        List {
            // 食事時間ごとにセクション表示（複数品対応）
            ForEach(mealsByType, id: \.0) { mealType, meals in
                Section {
                    ForEach(meals) { meal in
                        MealDishRow(meal: meal)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if canEdit { mealToEdit = meal }
                            }
                            .opacity(dayPlan.isPast ? 0.6 : 1.0)
                    }
                    .onDelete(perform: canEdit ? { indexSet in
                        indexSet.forEach { context.delete(meals[$0]) }
                    } : nil)
                } header: {
                    Text(mealType.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
            }

            // 未設定スロット（LLMが生成したがrecipeIDがないもの）の案内
            let unlinked = dayPlan.meals.filter { $0.recipeName != nil && $0.recipeID == nil }
            if !unlinked.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                        Text("\(unlinked.count)品のレシピがDB未登録です。タップして手動設定できます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if canEdit {
                Section {
                    Button {
                        showingAddMeal = true
                    } label: {
                        Label("料理を追加", systemImage: "plus.circle")
                            .foregroundStyle(.tint)
                    }

                    Button {
                        onRegenerateDay()
                    } label: {
                        Label("この日だけ再生成", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
        .sheet(item: $mealToEdit) { meal in
            MealSlotEditView(meal: meal)
        }
        .sheet(isPresented: $showingAddMeal) {
            AddMealSheet(dayPlan: dayPlan)
        }
    }
}

// MARK: - 料理追加シート

struct AddMealSheet: View {
    let dayPlan: DayPlan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMealType: MealType = .dinner
    @State private var showingRecipeSearch = false
    @State private var customName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("食事の時間帯") {
                    Picker("時間帯", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("レシピをDBから選ぶ") {
                    Button {
                        showingRecipeSearch = true
                    } label: {
                        Label("レシピを検索して追加", systemImage: "magnifyingglass")
                    }
                }

                Section("または料理名を直接入力") {
                    HStack {
                        TextField("例: 鶏の唐揚げ", text: $customName)
                        if !customName.isEmpty {
                            Button("追加") { addCustom() }
                                .font(.callout)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                }
            }
            .navigationTitle("料理を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showingRecipeSearch) {
                RecipeSearchView { recipe in
                    addFromRecipe(recipe)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func addFromRecipe(_ recipe: RecipeRecord) {
        let meal = PlannedMeal(mealType: selectedMealType)
        meal.recipeID   = recipe.id
        meal.recipeName = recipe.name
        meal.recipeURL  = recipe.url.isEmpty ? nil : recipe.url
        meal.notes      = ""
        context.insert(meal)
        dayPlan.meals.append(meal)
        dismiss()
    }

    private func addCustom() {
        let name = customName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let meal = PlannedMeal(mealType: selectedMealType)
        meal.recipeName = name
        // DBからも探してみる
        if let recipe = RecipeDatabase.shared.searchByName(name) {
            meal.recipeID   = recipe.id
            meal.recipeName = recipe.name
            meal.recipeURL  = recipe.url.isEmpty ? nil : recipe.url
        }
        meal.notes = ""
        context.insert(meal)
        dayPlan.meals.append(meal)
        dismiss()
    }
}

// MARK: - Meal Dish Row（1品＝1行）

private struct MealDishRow: View {
    let meal: PlannedMeal

    var body: some View {
        HStack(spacing: 12) {
            Text(visualEmoji)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                switch meal.mealOption {
                case .homeCooked:
                    if let name = meal.recipeName {
                        Text(name)
                            .font(.body)
                        if meal.recipeID == nil {
                            Text("レシピ未登録")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("未設定")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                case .diningOut:
                    Text("外食")
                        .font(.body)
                        .foregroundStyle(.secondary)
                case .skipped:
                    Text("スキップ")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()

            if meal.leftoverSourceMealID != nil {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var visualEmoji: String {
        if meal.mealOption == .skipped { return "⏭️" }
        if meal.mealOption == .diningOut { return "🍴" }
        let name = meal.recipeName ?? ""
        if name.contains("肉") || name.contains("ステーキ") { return "🥩" }
        if name.contains("魚") || name.contains("刺身") || name.contains("寿司") { return "🐟" }
        if name.contains("麺") || name.contains("パスタ") || name.contains("ラーメン") { return "🍜" }
        if name.contains("カレー")   { return "🍛" }
        if name.contains("サラダ")   { return "🥗" }
        if name.contains("スープ") || name.contains("汁") { return "🍲" }
        if name.contains("丼") || name.contains("ご飯")   { return "🍚" }
        if name.contains("パン")     { return "🍞" }
        if name.contains("卵") || name.contains("オムレツ") { return "🍳" }
        if name.isEmpty { return "❓" }
        return "🍽️"
    }
}
