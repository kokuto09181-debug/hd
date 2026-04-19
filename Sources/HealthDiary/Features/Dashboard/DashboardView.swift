import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [FamilyProfile]
    @Query(sort: \FoodLogEntry.loggedAt, order: .reverse) private var foodLogs: [FoodLogEntry]
    @Query private var mealPlans: [MealPlan]
    @StateObject private var healthKit = HealthKitService.shared

    private var todayLogs: [FoodLogEntry] {
        let start = Calendar.current.startOfDay(for: Date())
        return foodLogs.filter { $0.loggedAt >= start }
    }

    private var todayCaloriesConsumed: Double {
        todayLogs.reduce(0) { $0 + $1.totalCalories }
    }

    private var activeMealPlan: MealPlan? {
        mealPlans.first { $0.status == .confirmed }
    }

    private var todayDayPlan: DayPlan? {
        let today = Calendar.current.startOfDay(for: Date())
        return activeMealPlan?.days.first {
            Calendar.current.startOfDay(for: $0.date) == today
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    greetingSection
                    activityRingsSection
                    calorieBalanceSection
                    todayMealsSection
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle(greetingTitle)
            .navigationBarTitleDisplayMode(.large)
            .task {
                await healthKit.requestAuthorization()
            }
            .refreshable {
                await healthKit.fetchTodayData()
            }
        }
    }

    // MARK: - Sections

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "おはようございます"
        case 12..<18: return "こんにちは"
        default: return "こんばんは"
        }
    }

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let name = profiles.first?.members.first(where: { $0.isMainUser })?.name {
                    Text("\(name)さん")
                        .font(.headline)
                }
            }
            Spacer()
        }
    }

    private var activityRingsSection: some View {
        DashboardCard(title: "活動", systemImage: "figure.run") {
            HStack(spacing: 24) {
                ActivityMetric(
                    value: healthKit.todaySteps,
                    label: "歩数",
                    unit: "歩",
                    color: .green
                )
                Divider().frame(height: 50)
                ActivityMetric(
                    value: Int(healthKit.todayActiveCalories),
                    label: "消費",
                    unit: "kcal",
                    color: .orange
                )
                if let weight = healthKit.latestWeight {
                    Divider().frame(height: 50)
                    ActivityMetric(
                        value: Int(weight),
                        label: "体重",
                        unit: "kg",
                        color: .blue
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var calorieBalanceSection: some View {
        DashboardCard(title: "カロリー収支", systemImage: "flame") {
            HStack(spacing: 24) {
                ActivityMetric(
                    value: Int(todayCaloriesConsumed),
                    label: "摂取",
                    unit: "kcal",
                    color: .pink
                )
                Divider().frame(height: 50)
                ActivityMetric(
                    value: Int(healthKit.todayActiveCalories + healthKit.todayRestingCalories),
                    label: "消費",
                    unit: "kcal",
                    color: .orange
                )
                Divider().frame(height: 50)
                let balance = Int((healthKit.todayActiveCalories + healthKit.todayRestingCalories) - todayCaloriesConsumed)
                ActivityMetric(
                    value: balance,
                    label: "収支",
                    unit: "kcal",
                    color: balance >= 0 ? .green : .red
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var todayMealsSection: some View {
        DashboardCard(title: "今日の献立", systemImage: "fork.knife") {
            if let dayPlan = todayDayPlan, !dayPlan.meals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(dayPlan.meals) { meal in
                        HStack {
                            Text(meal.mealType.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)
                            Text(meal.recipeName ?? meal.mealOption.rawValue)
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
            } else {
                Text("今日の献立がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("クイックアクション")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(label: "食事を記録", systemImage: "camera.fill", color: .pink)
                QuickActionButton(label: "献立を作る", systemImage: "calendar.badge.plus", color: .teal)
            }
        }
    }
}

// MARK: - Components

private struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            content
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ActivityMetric: View {
    let value: Int
    let label: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct QuickActionButton: View {
    let label: String
    let systemImage: String
    let color: Color

    var body: some View {
        Button {} label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
