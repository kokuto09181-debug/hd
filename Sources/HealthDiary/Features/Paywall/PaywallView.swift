import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var store = StoreService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    heroSection
                    featuresSection
                    purchaseSection
                    footerNote
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.yellow)
            Text("プレミアムにアップグレード")
                .font(.title.bold())
            Text("すべての機能を制限なく使えます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var featuresSection: some View {
        VStack(spacing: 12) {
            FeatureRow(icon: "xmark.circle.fill", color: .red,
                       title: "広告を非表示",
                       description: "すっきりした操作体験")
            FeatureRow(icon: "calendar.badge.plus", color: .blue,
                       title: "無制限の献立プラン",
                       description: "何週間分でも作成可能")
            FeatureRow(icon: "bubble.left.and.bubble.right.fill", color: .purple,
                       title: "無制限のAIチャット",
                       description: "何度でも気軽に相談")
            FeatureRow(icon: "brain.fill", color: .green,
                       title: "オンデバイスAI",
                       description: "プライバシー重視・オフライン対応")
        }
        .padding(.horizontal)
    }

    private var purchaseSection: some View {
        Group {
            if let product = store.products.first {
                VStack(spacing: 12) {
                    Button {
                        Task {
                            isPurchasing = true
                            await store.purchase(product)
                            isPurchasing = false
                            if store.isPremium { dismiss() }
                        }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView().tint(.white).padding(.trailing, 4)
                            }
                            Text("月額 \(product.displayPrice) で始める")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isPurchasing)

                    Button("購入を復元する") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let err = store.purchaseError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                ProgressView("読み込み中…")
            }
        }
    }

    private var footerNote: some View {
        Text("いつでもキャンセル可能 · App Store経由で安全な決済")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
