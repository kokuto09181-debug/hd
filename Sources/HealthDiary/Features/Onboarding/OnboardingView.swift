import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "heart.text.square.fill",
            color: .pink,
            title: "HealthDiaryへようこそ",
            description: "家族の食事・健康をまとめて管理できるアプリです"
        ),
        OnboardingPage(
            systemImage: "fork.knife.circle.fill",
            color: .orange,
            title: "AI献立提案",
            description: "家族の人数や好みに合わせて、AIが複数日分の献立を自動で提案します"
        ),
        OnboardingPage(
            systemImage: "camera.fill",
            color: .blue,
            title: "食事を記録",
            description: "写真を撮るだけで食事を記録。カロリーや栄養バランスを自動で計算します"
        ),
        OnboardingPage(
            systemImage: "waveform.path.ecg",
            color: .green,
            title: "HealthKitと連携",
            description: "歩数・消費カロリー・体重など、Apple Healthのデータを自動で取得します"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if currentPage < pages.count - 1 {
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("次へ")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button("スキップ") {
                        finish()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        finish()
                    } label: {
                        Text("はじめる")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: page.systemImage)
                .font(.system(size: 80))
                .foregroundStyle(page.color)
                .padding(.bottom, 8)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            Spacer()
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        isPresented = false
    }
}

private struct OnboardingPage {
    let systemImage: String
    let color: Color
    let title: String
    let description: String
}
