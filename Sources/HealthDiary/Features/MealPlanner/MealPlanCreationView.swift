import SwiftUI
import SwiftData

struct MealPlanCreationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var history: [MealHistoryEntry]
    @Query private var profiles: [FamilyProfile]
    @Query(sort: \MealPlan.endDate, order: .reverse) private var allPlans: [MealPlan]

    @State private var startDate: Date
    @State private var numberOfDays = 4
    @State private var weekdaySlots: Set<MealType> = [.breakfast, .dinner]
    @State private var weekendSlots: Set<MealType> = [.breakfast, .lunch, .dinner]
    @State private var selectedConditions: Set<String> = []
    @State private var customCondition = ""
    @State private var isGenerating = false
    @State private var generationError: String? = nil
    @State private var overlapWarning: String? = nil

    private let presetConditions = ["時短メニュー優先", "魚料理を多めに", "肉料理を多めに", "子供が食べやすいもの", "野菜多め"]

    init() {
        // デフォルト開始日: 既存プランの翌日 or 明日
        _startDate = State(initialValue: Date())
    }

    var body: some View {
        NavigationStack {
            if isGenerating {
                generatingView
            } else {
                formView
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            startDateSection
            periodSection
            weekdaySlotsSection
            weekendSlotsSection
            conditionsSection
            if let warning = overlapWarning {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("既存プランと重なりますが作成できます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = generationError {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(error, systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Button("再試行") { Task { await generate() } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            generateSection
        }
        .navigationTitle("新しい献立")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
        }
        .onAppear { adjustDefaultStartDate() }
        .onChange(of: startDate) { _, _ in checkOverlap() }
        .onChange(of: numberOfDays) { _, _ in checkOverlap() }
    }

    private var startDateSection: some View {
        Section("開始日") {
            DatePicker("", selection: $startDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
        }
    }

    private var periodSection: some View {
        Section("期間") {
            Stepper(value: $numberOfDays, in: 2...14) {
                HStack {
                    Text("日数")
                    Spacer()
                    Text("\(numberOfDays)日間")
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("終了日")
                Spacer()
                Text(endDate, style: .date)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weekdaySlotsSection: some View {
        Section("平日の食事") {
            ForEach(MealType.allCases, id: \.self) { type in
                Toggle(type.rawValue, isOn: Binding(
                    get: { weekdaySlots.contains(type) },
                    set: { if $0 { weekdaySlots.insert(type) } else { weekdaySlots.remove(type) } }
                ))
            }
        }
    }

    private var weekendSlotsSection: some View {
        Section("休日の食事") {
            ForEach(MealType.allCases, id: \.self) { type in
                Toggle(type.rawValue, isOn: Binding(
                    get: { weekendSlots.contains(type) },
                    set: { if $0 { weekendSlots.insert(type) } else { weekendSlots.remove(type) } }
                ))
            }
        }
    }

    private var conditionsSection: some View {
        Section("こだわり条件（任意）") {
            ForEach(presetConditions, id: \.self) { cond in
                Toggle(cond, isOn: Binding(
                    get: { selectedConditions.contains(cond) },
                    set: { if $0 { selectedConditions.insert(cond) } else { selectedConditions.remove(cond) } }
                ))
            }
            HStack {
                TextField("自由入力", text: $customCondition)
                if !customCondition.isEmpty {
                    Button("追加") {
                        selectedConditions.insert(customCondition)
                        customCondition = ""
                    }
                    .font(.caption)
                }
            }
            if !selectedConditions.filter({ !presetConditions.contains($0) }).isEmpty {
                ForEach(selectedConditions.filter { !presetConditions.contains($0) }.sorted(), id: \.self) { cond in
                    HStack {
                        Text(cond).font(.subheadline)
                        Spacer()
                        Button { selectedConditions.remove(cond) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var generateSection: some View {
        Section {
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    Spacer()
                    Label("AIで献立を作る", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(weekdaySlots.isEmpty)
        }
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            VStack(spacing: 12) {
                Text("献立を考えています...")
                    .font(.title2.bold())
                ProgressView()
                    .scaleEffect(1.5)
            }

            Text("AIが\(numberOfDays)日分の献立を\n考えています。しばらくお待ちください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("献立を生成中")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Logic

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: numberOfDays - 1, to: startDate) ?? startDate
    }

    private func adjustDefaultStartDate() {
        // 既存プランの最も遅い endDate の翌日をデフォルトに
        if let latest = allPlans.max(by: { $0.endDate < $1.endDate }) {
            let next = Calendar.current.date(byAdding: .day, value: 1, to: latest.endDate) ?? Date()
            startDate = max(next, Date())
        } else {
            startDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        checkOverlap()
    }

    private func checkOverlap() {
        let newStart = Calendar.current.startOfDay(for: startDate)
        let newEnd = Calendar.current.startOfDay(for: endDate)
        let conflict = allPlans.first { plan in
            let s = Calendar.current.startOfDay(for: plan.startDate)
            let e = Calendar.current.startOfDay(for: plan.endDate)
            return newStart <= e && newEnd >= s
        }
        if let plan = conflict {
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            overlapWarning = "\(fmt.string(from: plan.startDate))〜\(fmt.string(from: plan.endDate)) のプランと期間が重なっています"
        } else {
            overlapWarning = nil
        }
    }

    private func generate() async {
        guard overlapWarning == nil, !weekdaySlots.isEmpty else { return }
        isGenerating = true
        generationError = nil

        let slotConfig = SlotConfig(
            weekday: MealType.allCases.filter { weekdaySlots.contains($0) },
            weekend: MealType.allCases.filter { weekendSlots.contains($0) }
        )
        var allConditions = Array(selectedConditions)
        if !customCondition.isEmpty { allConditions.append(customCondition) }

        let request = LLMPlanGenerator.GenerationRequest(
            numberOfDays: numberOfDays,
            startDate: startDate,
            slotConfig: slotConfig,
            familyProfile: profiles.first,
            recentHistory: history,
            conditions: allConditions
        )

        do {
            let plan = try await LLMPlanGenerator.shared.generate(request: request, context: context)
            plan.status = .draft
            dismiss()
        } catch {
            isGenerating = false
            generationError = error.localizedDescription
        }
    }
}
