import SwiftUI
import SwiftData

struct MealPlanCreationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var history: [MealHistoryEntry]
    @Query private var profiles: [FamilyProfile]

    @State private var startDate = Date()
    @State private var numberOfDays = 7
    @State private var weekdaySlots: Set<MealType> = [.breakfast, .dinner]
    @State private var weekendSlots: Set<MealType> = [.breakfast, .lunch, .dinner]
    @State private var isGenerating = false

    private let engine = MealPlanEngine()

    var body: some View {
        NavigationStack {
            Form {
                Section("期間") {
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)

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

                Section("平日の食事") {
                    ForEach(MealType.allCases, id: \.self) { type in
                        Toggle(type.rawValue, isOn: Binding(
                            get: { weekdaySlots.contains(type) },
                            set: { if $0 { weekdaySlots.insert(type) } else { weekdaySlots.remove(type) } }
                        ))
                    }
                }

                Section("週末の食事") {
                    ForEach(MealType.allCases, id: \.self) { type in
                        Toggle(type.rawValue, isOn: Binding(
                            get: { weekendSlots.contains(type) },
                            set: { if $0 { weekendSlots.insert(type) } else { weekendSlots.remove(type) } }
                        ))
                    }
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isGenerating ? "生成中..." : "献立を生成する")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(isGenerating || weekdaySlots.isEmpty)
                }
            }
            .navigationTitle("新しい献立")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: numberOfDays - 1, to: startDate) ?? startDate
    }

    private func generate() {
        isGenerating = true
        let config = SlotConfig(
            weekday: MealType.allCases.filter { weekdaySlots.contains($0) },
            weekend: MealType.allCases.filter { weekendSlots.contains($0) }
        )
        Task {
            let plan = engine.generatePlan(
                startDate: startDate,
                numberOfDays: numberOfDays,
                slotConfig: config,
                history: history,
                profile: profiles.first,
                context: context
            )
            plan.status = .confirmed
            dismiss()
        }
    }
}
