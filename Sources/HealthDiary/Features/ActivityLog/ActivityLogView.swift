import SwiftUI
import SwiftData
import HealthKit

struct ActivityLogView: View {
    @StateObject private var healthKit = HealthKitService.shared
    @Query(sort: \ActivityGoal.updatedAt, order: .reverse) private var goals: [ActivityGoal]
    @Query(sort: \ManualWorkout.performedAt, order: .reverse) private var workouts: [ManualWorkout]
    @Environment(\.modelContext) private var context
    @State private var showingAddWorkout = false
    @State private var showingGoalEdit = false

    private var goal: ActivityGoal { goals.first ?? ActivityGoal() }

    private var todayWorkouts: [ManualWorkout] {
        let start = Calendar.current.startOfDay(for: Date())
        return workouts.filter { $0.performedAt >= start }
    }

    var body: some View {
        NavigationStack {
            List {
                goalsSection
                hkDataSection
                manualWorkoutsSection
            }
            .navigationTitle("運動")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddWorkout = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await healthKit.requestAuthorization() }
            .sheet(isPresented: $showingAddWorkout) {
                ManualWorkoutAddView()
            }
            .sheet(isPresented: $showingGoalEdit) {
                ActivityGoalEditView(goal: goals.first)
            }
        }
    }

    // MARK: - Sections

    private var goalsSection: some View {
        Section {
            GoalProgressRow(
                label: "歩数",
                current: Double(healthKit.todaySteps),
                target: Double(goal.dailySteps),
                unit: "歩",
                color: .green,
                systemImage: "figure.walk"
            )
            GoalProgressRow(
                label: "消費カロリー",
                current: healthKit.todayActiveCalories,
                target: goal.dailyActiveCalories,
                unit: "kcal",
                color: .orange,
                systemImage: "flame.fill"
            )
        } header: {
            HStack {
                Text("目標")
                Spacer()
                Button("編集") { showingGoalEdit = true }
                    .font(.caption)
            }
        }
    }

    private var hkDataSection: some View {
        Section("Apple Health") {
            HKMetricRow(label: "消費カロリー（アクティブ）", value: Int(healthKit.todayActiveCalories), unit: "kcal", color: .orange)
            HKMetricRow(label: "消費カロリー（安静時）", value: Int(healthKit.todayRestingCalories), unit: "kcal", color: .yellow)
            HKMetricRow(label: "歩数", value: healthKit.todaySteps, unit: "歩", color: .green)
            if let weight = healthKit.latestWeight {
                HKMetricRow(label: "体重", value: Int(weight), unit: "kg", color: .blue)
            }
        }
    }

    private var manualWorkoutsSection: some View {
        Section("手動記録") {
            if todayWorkouts.isEmpty {
                Text("今日の記録がありません")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(todayWorkouts) { workout in
                    WorkoutRow(workout: workout)
                }
                .onDelete { indexSet in
                    indexSet.forEach { context.delete(todayWorkouts[$0]) }
                }
            }
        }
    }
}

// MARK: - Components

private struct GoalProgressRow: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    let systemImage: String

    private var progress: Double { min(current / max(target, 1), 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(label, systemImage: systemImage)
                    .foregroundStyle(color)
                Spacer()
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(color)
        }
        .padding(.vertical, 4)
    }
}

private struct HKMetricRow: View {
    let label: String
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WorkoutRow: View {
    let workout: ManualWorkout

    var body: some View {
        HStack {
            Image(systemName: workoutIcon)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutType.rawValue)
                    .font(.body)
                Text("\(workout.durationMinutes)分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(workout.estimatedCalories)) kcal")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
        }
    }

    private var workoutIcon: String {
        switch workout.workoutType {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .strength: return "dumbbell.fill"
        case .yoga: return "figure.yoga"
        case .other: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Add Workout

struct ManualWorkoutAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var workoutType: WorkoutType = .running
    @State private var durationMinutes = 30
    @State private var customCalories = ""

    private var estimatedCalories: Double {
        if let custom = Double(customCalories) { return custom }
        return Double(durationMinutes) * metPerMinute
    }

    private var metPerMinute: Double {
        switch workoutType {
        case .running: return 10.0
        case .walking: return 4.0
        case .cycling: return 7.5
        case .swimming: return 8.0
        case .strength: return 5.0
        case .yoga: return 3.0
        case .other: return 5.0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("運動の種類") {
                    Picker("種類", selection: $workoutType) {
                        ForEach(WorkoutType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }

                Section("時間") {
                    Stepper(value: $durationMinutes, in: 5...300, step: 5) {
                        HStack {
                            Text("時間")
                            Spacer()
                            Text("\(durationMinutes)分")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("消費カロリー") {
                    HStack {
                        Text("推定")
                        Spacer()
                        Text("\(Int(estimatedCalories)) kcal")
                            .foregroundStyle(.orange)
                    }
                    HStack {
                        Text("手動修正")
                        Spacer()
                        TextField("kcal", text: $customCalories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("運動を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private func save() {
        let workout = ManualWorkout(
            workoutType: workoutType,
            durationMinutes: durationMinutes,
            estimatedCalories: estimatedCalories
        )
        context.insert(workout)
        dismiss()
    }
}

// MARK: - Goal Edit

struct ActivityGoalEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let goal: ActivityGoal?

    @State private var dailySteps: Double
    @State private var dailyCalories: Double

    init(goal: ActivityGoal?) {
        self.goal = goal
        _dailySteps = State(initialValue: Double(goal?.dailySteps ?? 8000))
        _dailyCalories = State(initialValue: goal?.dailyActiveCalories ?? 500)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("1日の目標") {
                    HStack {
                        Text("歩数")
                        Spacer()
                        TextField("歩", value: $dailySteps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("歩")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("消費カロリー")
                        Spacer()
                        TextField("kcal", value: $dailyCalories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kcal")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("目標を設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        if let existing = goal {
            existing.dailySteps = Int(dailySteps)
            existing.dailyActiveCalories = dailyCalories
            existing.updatedAt = Date()
        } else {
            let newGoal = ActivityGoal(dailySteps: Int(dailySteps), dailyActiveCalories: dailyCalories)
            context.insert(newGoal)
        }
        dismiss()
    }
}
