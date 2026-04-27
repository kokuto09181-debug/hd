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
                        Label("次の献立を作る", systemImage: "plus")
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
        Text(plan.status == .shopping ? "買い出し済み" : "下書き")
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
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog("この献立を全部作り直しますか？", isPresented: $showingRegenerateConfirm, titleVisibility: .visible) {
            Button("同じ条件で再生成", role: .destructive) { Task { await regenerateAll() } }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog("買い出しが完了したら確定してください", isPresented: $showingShoppingConfirm, titleVisibility: .visible) {
            Button("買い出し済みにする") { plan.status = .shopping }
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

    private var navigationTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return "\(fmt.string(from: plan.startDate))〜\(fmt.string(from: plan.endDate))"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if plan.status == .draft {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingRegenerateConfirm = true
                    } label: {
                        Label("全体を再生成", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        showingShoppingConfirm = true
                    } label: {
                        Label("買い出し済みにする", systemImage: "cart.badge.checkmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
        // 既存の DayPlan をすべて削除
        plan.days.forEach { context.delete($0) }
        plan.days.removeAll()
        do {
            let request = makeRequest()
            let prompt = LLMPlanGenerator.shared.buildPublicPrompt(request: request)
            let llmCtx = LLMContext.mealPlan(
                days: request.numberOfDays,
                familySize: request.familyProfile?.members.count ?? 1
            )
            let jsonText = try await LLMService.shared.generate(prompt: prompt, context: llmCtx)
            try LLMPlanGenerator.shared.applyPlanJSON(jsonText, to: plan, request: request, context: context)
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

    private var sortedMeals: [PlannedMeal] {
        let order: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        return dayPlan.meals.sorted { a, b in
            (order.firstIndex(of: a.mealType) ?? 99) < (order.firstIndex(of: b.mealType) ?? 99)
        }
    }

    private var canEdit: Bool {
        plan.status == .draft && !dayPlan.isPast
    }

    var body: some View {
        List {
            Section {
                ForEach(sortedMeals) { meal in
                    MealSlotRow(meal: meal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if canEdit { mealToEdit = meal }
                        }
                        .opacity(dayPlan.isPast ? 0.5 : 1.0)
                }
                .onDelete { indexSet in
                    guard canEdit else { return }
                    indexSet.forEach { context.delete(sortedMeals[$0]) }
                }
            }

            if canEdit {
                Section {
                    Menu {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Button(type.rawValue) {
                                let meal = PlannedMeal(mealType: type)
                                context.insert(meal)
                                dayPlan.meals.append(meal)
                            }
                        }
                    } label: {
                        Label("食事を追加", systemImage: "plus.circle")
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
    }
}

// MARK: - Meal Slot Row

private struct MealSlotRow: View {
    let meal: PlannedMeal

    var body: some View {
        HStack(spacing: 12) {
            Text(meal.mealType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            Text(visualEmoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                switch meal.mealOption {
                case .homeCooked:
                    Text(meal.recipeName ?? "未設定")
                        .font(.body)
                        .foregroundStyle(meal.recipeName == nil ? .secondary : .primary)
                case .diningOut:
                    Text("外食").font(.body).foregroundStyle(.secondary)
                case .skipped:
                    Text("スキップ").font(.body).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if meal.leftoverSourceMealID != nil {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
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
        if name.contains("カレー") { return "🍛" }
        if name.contains("サラダ") { return "🥗" }
        if name.contains("スープ") || name.contains("汁") { return "🍲" }
        if name.contains("丼") || name.contains("ご飯") { return "🍚" }
        if name.contains("パン") { return "🍞" }
        if name.contains("卵") || name.contains("オムレツ") { return "🍳" }
        if name.isEmpty { return "❓" }
        return "🍽️"
    }
}
