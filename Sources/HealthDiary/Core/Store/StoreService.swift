import Foundation
import StoreKit

@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    @Published var isPremium = false
    @Published var products: [Product] = []
    @Published var purchaseError: String?

    private let productID = "com.healthdiary.app.premium.monthly"
    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = startTransactionListener()
        Task {
            await loadProducts()
            await refreshPurchaseStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [productID])
        } catch {
            print("StoreKit: failed to load products – \(error)")
        }
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else { return }
                await tx.finish()
                isPremium = true
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func refreshPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == productID {
                isPremium = true
                return
            }
        }
    }

    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await MainActor.run { [weak self] in
                        if tx.productID == self?.productID {
                            self?.isPremium = true
                        }
                    }
                    await tx.finish()
                }
            }
        }
    }
}
