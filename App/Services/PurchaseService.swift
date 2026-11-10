import Foundation
import Observation
import StoreKit

@MainActor @Observable final class PurchaseService {
  static let productIDs = [
    "app.ripple.pro.yearly", "app.ripple.pro.monthly", "app.ripple.pro.lifetime",
  ]
  private(set) var products: [Product] = []
  private(set) var isPro = false
  private(set) var isLoading = false
  private(set) var isPurchasing = false
  private(set) var isVerified = false
  var message: String?
  @ObservationIgnored private var listener: Task<Void, Never>?
  @ObservationIgnored private var refreshGeneration = 0
  deinit { listener?.cancel() }

  func start() async {
    guard listener == nil else { return }
    listener = Task { [weak self] in
      for await result in Transaction.updates {
        guard !Task.isCancelled else { return }
        guard case .verified(let transaction) = result,
          Self.productIDs.contains(transaction.productID)
        else { continue }
        await self?.refreshEntitlements()
        await transaction.finish()
      }
    }
    await refreshEntitlements()
  }
  func loadProducts() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let found = try await Product.products(for: Self.productIDs)
      products = Self.productIDs.compactMap { id in found.first { $0.id == id } }
      if found.isEmpty {
        message =
          "Plans are currently unavailable. Try again when you’re connected to the App Store."
      }
    } catch { message = "Plans couldn’t be loaded. Check your connection and try again." }
  }
  func refreshEntitlements() async {
    refreshGeneration += 1
    let generation = refreshGeneration
    var active = false
    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result,
        Self.productIDs.contains(transaction.productID),
        transaction.revocationDate == nil, !transaction.isUpgraded,
        transaction.expirationDate.map({ $0 > .now }) ?? true
      else { continue }
      active = true
    }
    guard generation == refreshGeneration else { return }
    isPro = active
    isVerified = true
    // Display-only cache. Access always comes from StoreKit's verified, offline-capable sequence.
    UserDefaults.standard.set(active, forKey: "lastVerifiedProStatus")
  }
  func purchase(_ product: Product) async {
    guard !isPurchasing, Self.productIDs.contains(product.id) else { return }
    isPurchasing = true
    message = nil
    defer { isPurchasing = false }
    do {
      switch try await product.purchase() {
      case .success(let result):
        guard case .verified(let transaction) = result,
          Self.productIDs.contains(transaction.productID)
        else {
          message =
            "The App Store couldn’t verify this purchase. Use Restore Purchases to try again."
          return
        }
        await refreshEntitlements()
        await transaction.finish()
      case .pending:
        message =
          "Your purchase is awaiting approval. Pro will unlock when the App Store confirms it."
      case .userCancelled: break
      @unknown default: message = "The purchase hasn’t completed. Please try again."
      }
    } catch { message = "The purchase couldn’t be completed. Please try again." }
  }
  func restore() async {
    guard !isPurchasing else { return }
    isPurchasing = true
    message = nil
    defer { isPurchasing = false }
    do {
      try await StoreKit.AppStore.sync()
      await refreshEntitlements()
      message =
        isPro
        ? "Your Pro access is restored."
        : "No active Ripple Pro purchase was found for this Apple Account."
    } catch { message = "Purchases couldn’t be restored. Check your connection and try again." }
  }
}
