import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Query(sort: \ShoppingList.generatedAt, order: .reverse) private var lists: [ShoppingList]
    @Query(sort: \MealPlan.startDate, order: .reverse) private var allPlans: [MealPlan]
    private var confirmedPlans: [MealPlan] { allPlans.filter { $0.status == .confirmed } }
    @Environment(\.modelContext) private var context
    @State private var showingGenerateConfirm = false

    private var activeList: ShoppingList? { lists.first }

    var body: some View {
        NavigationStack {
            Group {
                if let list = activeList, !list.items.isEmpty {
                    ShoppingItemsView(list: list)
                } else {
                    EmptyShoppingListView(
                        hasPlan: !confirmedPlans.isEmpty,
                        onGenerate: { showingGenerateConfirm = true }
                    )
                }
            }
            .navigationTitle("買い出し")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if activeList != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingGenerateConfirm = true
                            } label: {
                                Label("再生成", systemImage: "arrow.clockwise")
                            }
                            Button(role: .destructive) {
                                if let list = activeList {
                                    context.delete(list)
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog("買い出しリストを生成しますか？", isPresented: $showingGenerateConfirm, titleVisibility: .visible) {
                Button("生成する") { generateList() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("確定済みの献立から食材をまとめます")
            }
        }
    }

    private func generateList() {
        guard let plan = confirmedPlans.first else { return }
        if let existing = activeList { context.delete(existing) }
        let engine = MealPlanEngine()
        _ = engine.generateShoppingList(from: plan, context: context)
    }
}

// MARK: - Empty State

private struct EmptyShoppingListView: View {
    let hasPlan: Bool
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("買い出しリストがありません")
                    .font(.title2.bold())
                Text(hasPlan
                     ? "確定済みの献立から\n食材を自動でまとめます"
                     : "先に献立を確定してください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if hasPlan {
                Button(action: onGenerate) {
                    Text("リストを生成する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
            }
        }
        .padding()
    }
}

// MARK: - Shopping Items

private struct ShoppingItemsView: View {
    @Bindable var list: ShoppingList

    private var groupedItems: [(IngredientCategory, [ShoppingItem])] {
        let sorted = list.items.sorted { $0.name < $1.name }
        let grouped = Dictionary(grouping: sorted) { $0.category }
        return IngredientCategory.allCases
            .compactMap { cat in
                guard let items = grouped[cat], !items.isEmpty else { return nil }
                return (cat, items)
            }
    }

    private var checkedCount: Int { list.items.filter { $0.isChecked }.count }
    private var totalCount: Int { list.items.count }

    var body: some View {
        List {
            Section {
                ProgressView(value: Double(checkedCount), total: Double(max(totalCount, 1)))
                    .tint(.green)
                HStack {
                    Text("\(checkedCount) / \(totalCount) 完了")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if checkedCount == totalCount && totalCount > 0 {
                        Label("買い出し完了！", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            ForEach(groupedItems, id: \.0) { category, items in
                Section(category.rawValue) {
                    ForEach(items) { item in
                        ShoppingItemRow(item: item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Item Row

private struct ShoppingItemRow: View {
    @Bindable var item: ShoppingItem
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isChecked.toggle()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                Text(formattedAmount)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !item.usedInRecipes.isEmpty {
                Button {
                    showingDetail = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showingDetail) {
            ShoppingItemDetailView(item: item)
        }
    }

    private var formattedAmount: String {
        let amount = item.totalAmount
        if amount == amount.rounded() {
            return "\(Int(amount)) \(item.unit)"
        }
        return String(format: "%.1f %@", amount, item.unit)
    }
}

// MARK: - Item Detail

private struct ShoppingItemDetailView: View {
    let item: ShoppingItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("使用するレシピ") {
                    ForEach(item.usedInRecipes, id: \.self) { recipe in
                        Label(recipe, systemImage: "fork.knife")
                    }
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
