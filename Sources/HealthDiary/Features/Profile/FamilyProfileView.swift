import SwiftUI
import SwiftData

struct FamilyProfileView: View {
    @Query private var profiles: [FamilyProfile]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    MemberListView(profile: profile)
                } else {
                    EmptyProfileView {
                        createProfile()
                    }
                }
            }
            .navigationTitle("家族")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func createProfile() {
        let profile = FamilyProfile()
        context.insert(profile)
    }
}

// MARK: - Member List

private struct MemberListView: View {
    @Bindable var profile: FamilyProfile
    @Environment(\.modelContext) private var context
    @State private var showingAddMember = false

    var body: some View {
        List {
            Section {
                ForEach(profile.members) { member in
                    NavigationLink {
                        MemberEditView(member: member)
                    } label: {
                        MemberRow(member: member)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { context.delete(profile.members[$0]) }
                }
            } header: {
                Text("メンバー \(profile.members.count)人")
            }

            Section {
                Button {
                    showingAddMember = true
                } label: {
                    Label("メンバーを追加", systemImage: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMember) {
            MemberAddView(profile: profile)
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: FamilyMember

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: member.ageGroup == .adult ? "person.fill" : "figure.child")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(member.ageGroup.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !member.allergies.isEmpty {
                        Text("アレルギーあり")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if member.isMainUser {
                Spacer()
                Text("メイン")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15))
                    .foregroundStyle(.tint)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

private struct EmptyProfileView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("家族を設定しましょう")
                    .font(.title2.bold())
                Text("家族構成を登録すると\n献立の提案が最適化されます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onStart) {
                Text("はじめる")
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
