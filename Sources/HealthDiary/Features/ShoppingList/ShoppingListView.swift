import SwiftUI
import SwiftData

// MARK: - Root View

struct ShoppingListView: View {
    @Query(sort: \ShoppingList.generatedAt, order: .reverse) private var lists: [ShoppingList]
    @Query(sort: \MealPlan.startDate, order: .reverse) private var allPlans: [MealPlan]
    @Query(sort: \PantryItem.addedAt, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var aliases: [IngredientAlias]
    @Environment(\.modelContext) private var context

    @State private var selectedTab: ShoppingTab = .shopping
    @State private var showingGenerateConfirm = false
    @State private var showingAddPantry = false

    private var confirmedPlans: [MealPlan] { allPlans.filter { $0.status == .shopping } }
    private var activeList: ShoppingList? { lists.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("タブ", selection: $selectedTab) {
                    ForEach(ShoppingTab.allCases, id: \.self) { tab in
                        Text(tab.label).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)

                Group {
                    switch selectedTab {
                    case .shopping:
                        shoppingContent
                    case .pantry:
                        PantryView(
                            pantryItems: pantryItems,
                            showingAdd: $showingAddPantry
                        )
                    }
                }
            }
            .navigationTitle("買い出し・パントリー")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .confirmationDialog(
                "買い出しリストを生成しますか？",
                isPresented: $showingGenerateConfirm,
                titleVisibility: .visible
            ) {
                Button("生成する") { generateList() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("確定済みの献立から食材をまとめます")
            }
            .sheet(isPresented: $showingAddPantry) {
                PantryAddView()
            }
        }
    }

    // MARK: - Shopping Content

    @ViewBuilder
    private var shoppingContent: some View {
        if let list = activeList, !list.items.isEmpty {
            ShoppingItemsView(
                list: list,
                pantryItems: pantryItems,
                aliases: aliases
            )
        } else {
            EmptyShoppingListView(
                hasPlan: !confirmedPlans.isEmpty,
                onGenerate: { showingGenerateConfirm = true }
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if selectedTab == .shopping {
            if activeList != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingGenerateConfirm = true
                        } label: {
                            Label("再生成", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            if let list = activeList { context.delete(list) }
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddPantry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Generate

    private func generateList() {
        guard let plan = confirmedPlans.first else { return }
        if let existing = activeList { context.delete(existing) }
        let engine = MealPlanEngine()
        _ = engine.generateShoppingList(from: plan, context: context, aliases: aliases)
    }
}

// MARK: - Tab

private enum ShoppingTab: CaseIterable {
    case shopping, pantry

    var label: String {
        switch self {
        case .shopping: return "買い出し"
        case .pantry: return "パントリー"
        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shopping Items

private struct ShoppingItemsView: View {
    @Bindable var list: ShoppingList
    let pantryItems: [PantryItem]
    let aliases: [IngredientAlias]

    @Environment(\.modelContext) private var context

    private let normService = IngredientNormalizationService.shared

    // パントリーにある食材の正規化済みセット
    private var pantryCanonicals: Set<String> {
        Set(pantryItems.map {
            normService.normalize($0.name, aliases: aliases)
        })
    }

    // 各 ShoppingItem がパントリーにあるかどうか
    private func isInPantry(_ item: ShoppingItem) -> Bool {
        let canonical = normService.normalize(item.name, aliases: aliases)
        return pantryCanonicals.contains(canonical)
    }

    // 「家にあるかも」カテゴリ
    private var pantryMatchItems: [ShoppingItem] {
        list.items.filter { !$0.isChecked && isInPantry($0) }
    }

    // カテゴリ別の通常アイテム（パントリーにないもの・未チェック）
    private var groupedBuyItems: [(IngredientCategory, [ShoppingItem])] {
        let items = list.items.filter { !$0.isChecked && !isInPantry($0) }
        return grouped(items)
    }

    // チェック済み
    private var checkedItems: [ShoppingItem] {
        list.items.filter { $0.isChecked }
    }

    private var checkedCount: Int { list.items.filter { $0.isChecked }.count }
    private var totalCount: Int { list.items.count }

    var body: some View {
        List {
            // プログレス
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

            // 家にあるかも
            if !pantryMatchItems.isEmpty {
                Section {
                    ForEach(pantryMatchItems) { item in
                        ShoppingItemRow(item: item, onCheck: { handleCheck(item) })
                            .opacity(0.55)
                    }
                } header: {
                    Label("家にあるかも", systemImage: "house.fill")
                        .foregroundStyle(.teal)
                }
            }

            // 買うもの
            ForEach(groupedBuyItems, id: \.0) { category, items in
                Section(category.rawValue) {
                    ForEach(items) { item in
                        ShoppingItemRow(item: item, onCheck: { handleCheck(item) })
                    }
                }
            }

            // チェック済み（折り畳み的に最下部）
            if !checkedItems.isEmpty {
                Section {
                    ForEach(checkedItems) { item in
                        ShoppingItemRow(item: item, onCheck: { handleCheck(item) })
                    }
                } header: {
                    Text("チェック済み")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: チェック時：パントリー自動追加

    private func handleCheck(_ item: ShoppingItem) {
        let newChecked = !item.isChecked
        item.isChecked = newChecked

        guard newChecked else { return }
        // パントリーに追加（既存チェック）
        let canonical = normService.normalize(item.name, aliases: aliases)
        let alreadyExists = pantryItems.contains {
            normService.normalize($0.name, aliases: aliases) == canonical
        }
        guard !alreadyExists else { return }

        let pantryItem = PantryItem(
            name: canonical,
            amount: item.totalAmount > 0 ? item.totalAmount : nil,
            unit: item.unit.isEmpty ? nil : item.unit,
            category: item.category,
            source: .shopping
        )
        context.insert(pantryItem)
    }

    private func grouped(_ items: [ShoppingItem]) -> [(IngredientCategory, [ShoppingItem])] {
        let sorted = items.sorted { $0.name < $1.name }
        let dict = Dictionary(grouping: sorted) { $0.category }
        return IngredientCategory.allCases.compactMap { cat in
            guard let catItems = dict[cat], !catItems.isEmpty else { return nil }
            return (cat, catItems)
        }
    }
}

// MARK: - Item Row

private struct ShoppingItemRow: View {
    @Bindable var item: ShoppingItem
    let onCheck: () -> Void
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCheck) {
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
        guard amount > 0 else { return item.unit }   // 0 は "※食材要確認" などのメモ行
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

// MARK: - Pantry View

private struct PantryView: View {
    let pantryItems: [PantryItem]
    @Binding var showingAdd: Bool
    @Environment(\.modelContext) private var context

    private var grouped: [(IngredientCategory, [PantryItem])] {
        let dict = Dictionary(grouping: pantryItems) { $0.category }
        return IngredientCategory.allCases.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        Group {
            if pantryItems.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(grouped, id: \.0) { category, items in
                        Section(category.rawValue) {
                            ForEach(items) { item in
                                PantryItemRow(item: item)
                            }
                            .onDelete { indexSet in
                                indexSet.forEach { context.delete(items[$0]) }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "refrigerator")
                .font(.system(size: 56))
                .foregroundStyle(.teal.opacity(0.6))

            VStack(spacing: 6) {
                Text("パントリーは空です")
                    .font(.title3.bold())
                Text("買い出しでチェックした食材が\n自動的に追加されます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingAdd = true
            } label: {
                Label("手動で追加", systemImage: "plus.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint.opacity(0.12))
                    .foregroundStyle(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pantry Item Row

private struct PantryItemRow: View {
    @Bindable var item: PantryItem

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)

                HStack(spacing: 4) {
                    if let amount = item.amount {
                        let amtStr = amount == amount.rounded()
                            ? "\(Int(amount))"
                            : String(format: "%.1f", amount)
                        Text("\(amtStr)\(item.unit ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    sourceLabel
                }
            }

            Spacer()

            Text(item.addedAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var sourceLabel: some View {
        let (text, color): (String, Color) = {
            switch item.source {
            case .shopping: return ("買い出し", .teal)
            case .manual: return ("手動", .orange)
            case .leftover: return ("残り物", .purple)
            }
        }()
        return Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Pantry Add View

struct PantryAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountText = ""
    @State private var unit = ""
    @State private var category: IngredientCategory = .other
    @State private var source: PantrySource = .manual

    var body: some View {
        NavigationStack {
            Form {
                Section("食材") {
                    TextField("名前（例: 玉ねぎ）", text: $name)

                    Picker("カテゴリ", selection: $category) {
                        ForEach(IngredientCategory.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }

                Section("数量（任意）") {
                    HStack {
                        TextField("量", text: $amountText)
                            .keyboardType(.decimalPad)
                        TextField("単位（g, 個, 本...）", text: $unit)
                    }
                }

                Section("追加方法") {
                    Picker("ソース", selection: $source) {
                        Text("手動").tag(PantrySource.manual)
                        Text("残り物").tag(PantrySource.leftover)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("パントリーに追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let amount = Double(amountText)
        let unitTrimmed = unit.trimmingCharacters(in: .whitespaces)
        let item = PantryItem(
            name: trimmed,
            amount: amount,
            unit: unitTrimmed.isEmpty ? nil : unitTrimmed,
            category: category,
            source: source
        )
        context.insert(item)
        dismiss()
    }
}
