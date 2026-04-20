import SwiftUI
import SwiftData

struct MealPlannerView: View {
    @Query(sort: \MealPlan.startDate, order: .reverse) private var plans: [MealPlan]
    @Environment(\.modelContext) private var context
    @State private var showingCreation = false

    private var activePlan: MealPlan? { plans.first { $0.status == .confirmed } }

    var body: some View {
        NavigationStack {
            Group {
                if let plan = activePlan {
                    MealPlanDetailView(plan: plan)
                } else {
                    EmptyMealPlanView { showingCreation = true }
                }
            }
            .navigationTitle("献立")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreation = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreation) {
                MealPlanCreationView()
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
                Text("家族の好みに合わせた\n複数日の献立を自動提案します")
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

// MARK: - Plan Detail

struct MealPlanDetailView: View {
    @Bindable var plan: MealPlan
    @Environment(\.modelContext) private var context
    @State private var selectedDayIndex = 0

    private var sortedDays: [DayPlan] {
        plan.days.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            daySelector
            Divider()
            if sortedDays.indices.contains(selectedDayIndex) {
                DayPlanView(dayPlan: sortedDays[selectedDayIndex])
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 {
                        // 左スワイプ → 次の日
                        if selectedDayIndex < sortedDays.count - 1 {
                            withAnimation { selectedDayIndex += 1 }
                        }
                    } else if value.translation.width > 40 {
                        // 右スワイプ → 前の日
                        if selectedDayIndex > 0 {
                            withAnimation { selectedDayIndex -= 1 }
                        }
                    }
                }
        )
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sortedDays.enumerated()), id: \.element.id) { index, day in
                    DayTab(date: day.date, isSelected: index == selectedDayIndex) {
                        selectedDayIndex = index
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}

private struct DayTab: View {
    let date: Date
    let isSelected: Bool
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
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Plan

struct DayPlanView: View {
    @Bindable var dayPlan: DayPlan
    @Environment(\.modelContext) private var context
    @State private var mealToEdit: PlannedMeal? = nil

    private var sortedMeals: [PlannedMeal] {
        let order: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        return dayPlan.meals.sorted { a, b in
            (order.firstIndex(of: a.mealType) ?? 99) < (order.firstIndex(of: b.mealType) ?? 99)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(sortedMeals) { meal in
                    MealSlotRow(meal: meal)
                        .contentShape(Rectangle())
                        .onTapGesture { mealToEdit = meal }
                }
                .onDelete { indexSet in
                    indexSet.forEach { context.delete(sortedMeals[$0]) }
                }
            }

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
            }
        }
        .sheet(item: $mealToEdit) { meal in
            MealSlotEditView(meal: meal)
        }
    }
}

private struct MealSlotRow: View {
    let meal: PlannedMeal

    var body: some View {
        HStack(spacing: 12) {
            Text(meal.mealType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                switch meal.mealOption {
                case .homeCooked:
                    Text(meal.recipeName ?? "未設定")
                        .font(.body)
                        .foregroundStyle(meal.recipeName == nil ? .secondary : .primary)
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
        }
        .padding(.vertical, 2)
    }
}
