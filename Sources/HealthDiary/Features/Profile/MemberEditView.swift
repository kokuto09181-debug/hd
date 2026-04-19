import SwiftUI
import SwiftData

struct MemberEditView: View {
    @Bindable var member: FamilyMember
    @Environment(\.dismiss) private var dismiss
    @State private var newAllergy = ""
    @State private var newPreference = ""
    @State private var newDislike = ""

    var body: some View {
        Form {
            Section("基本情報") {
                HStack {
                    Text("名前")
                    Spacer()
                    TextField("名前", text: $member.name)
                        .multilineTextAlignment(.trailing)
                }

                Picker("年齢区分", selection: $member.ageGroup) {
                    ForEach(AgeGroup.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }

                Toggle("メインユーザー（自分）", isOn: $member.isMainUser)
            }

            Section("アレルギー") {
                ForEach(member.allergies, id: \.self) { item in
                    Text(item)
                }
                .onDelete { member.allergies.remove(atOffsets: $0) }

                HStack {
                    TextField("例：卵、乳製品", text: $newAllergy)
                    Button("追加") {
                        let trimmed = newAllergy.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        member.allergies.append(trimmed)
                        newAllergy = ""
                    }
                    .disabled(newAllergy.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("好きな食べ物") {
                ForEach(member.preferences, id: \.self) { item in
                    Text(item)
                }
                .onDelete { member.preferences.remove(atOffsets: $0) }

                HStack {
                    TextField("例：魚料理、和食", text: $newPreference)
                    Button("追加") {
                        let trimmed = newPreference.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        member.preferences.append(trimmed)
                        newPreference = ""
                    }
                    .disabled(newPreference.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("苦手な食べ物") {
                ForEach(member.dislikes, id: \.self) { item in
                    Text(item)
                }
                .onDelete { member.dislikes.remove(atOffsets: $0) }

                HStack {
                    TextField("例：辛い食べ物、セロリ", text: $newDislike)
                    Button("追加") {
                        let trimmed = newDislike.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        member.dislikes.append(trimmed)
                        newDislike = ""
                    }
                    .disabled(newDislike.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle(member.name.isEmpty ? "メンバー編集" : member.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MemberAddView: View {
    let profile: FamilyProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ageGroup: AgeGroup = .adult
    @State private var isMainUser = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $name)

                    Picker("年齢区分", selection: $ageGroup) {
                        ForEach(AgeGroup.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }

                    Toggle("メインユーザー（自分）", isOn: $isMainUser)
                }
            }
            .navigationTitle("メンバーを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let member = FamilyMember(name: name.isEmpty ? "名前未設定" : name, ageGroup: ageGroup, isMainUser: isMainUser)
                        context.insert(member)
                        profile.members.append(member)
                        dismiss()
                    }
                }
            }
        }
    }
}
