import StoreKit
import SwiftUI

struct PaywallView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var selected = "app.ripple.pro.yearly"
  @State private var trialEligible = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          RippleMark(size: 90).frame(maxWidth: .infinity).padding(.vertical, 12)
          Text("Follow every\nconnection.").font(
            .system(.largeTitle, design: .serif, weight: .medium))
          Text("Ripple Pro").font(.headline).foregroundStyle(Palette.accent)
          VStack(alignment: .leading, spacing: 18) {
            Label("Unlimited chains, at your pace", systemImage: "infinity")
            Label("Peel sentences back, layer by layer", systemImage: "arrow.uturn.backward")
            Label("Practice any rule whenever you like", systemImage: "square.grid.2x2")
          }.font(.subheadline)
          if store.purchases.isLoading { ProgressView("Loading plans…").frame(maxWidth: .infinity) }
          ForEach(store.purchases.products, id: \.id) { product in
            Button {
              selected = product.id
              trialEligible = false
              Task { await eligibility(product) }
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 7) {
                  Text(planName(product.id)).font(.headline)
                  Text(
                    product.id.hasSuffix("lifetime")
                      ? "One purchase, lifetime access"
                      : product.id.hasSuffix("yearly") ? "Billed yearly" : "Billed monthly"
                  ).font(.caption).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Text(product.displayPrice).font(.headline)
                Image(systemName: selected == product.id ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(Palette.accent)
              }.surfaceCard()
            }.buttonStyle(.plain).accessibilityIdentifier("plan.\(product.id)")
          }
          if let message = store.purchases.message {
            Text(message).font(.subheadline).foregroundStyle(Palette.secondary)
          }
          if let product = store.purchases.products.first(where: { $0.id == selected }) {
            PrimaryButton(
              store.purchases.isPurchasing
                ? "Waiting for the App Store…"
                : trialEligible ? "Start free trial" : "Continue with \(planName(product.id))",
              enabled: !store.purchases.isPurchasing
            ) {
              Task {
                await store.purchases.purchase(product)
                if store.purchases.isPro {
                  store.backend.event("purchase_complete", ["product_id": product.id])
                  dismiss()
                }
              }
            }
            .accessibilityIdentifier("paywall.purchase")
            Text(terms(product)).font(.caption).foregroundStyle(Palette.secondary).lineSpacing(3)
          } else if !store.purchases.isLoading {
            Button("Reload plans") { Task { await store.purchases.loadProducts() } }.buttonStyle(
              .bordered)
          }
          Button("Restore Purchases") {
            Task {
              await store.purchases.restore()
              if store.purchases.isPro { dismiss() }
            }
          }.frame(maxWidth: .infinity, minHeight: 44).disabled(store.purchases.isPurchasing)
          HStack {
            NavigationLink("Privacy") { PrivacyView() }
            Spacer()
            Link(
              "Terms",
              destination: URL(
                string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
          }.font(.caption).frame(minHeight: 44)
        }.padding(24).readingWidth()
      }.background(Palette.paper).toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }.disabled(store.purchases.isPurchasing)
            .accessibilityIdentifier("paywall.close")
        }
      }
    }.task {
      await store.purchases.loadProducts()
      if let product = store.purchases.products.first {
        selected = product.id
        await eligibility(product)
      }
    }
    .onChange(of: store.purchases.isPro) { _, active in if active { dismiss() } }
  }
  private func planName(_ id: String) -> String {
    id.hasSuffix("yearly") ? "Yearly" : id.hasSuffix("monthly") ? "Monthly" : "Lifetime"
  }
  private func eligibility(_ product: Product) async {
    let hasFreeOffer = product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    let eligible =
      hasFreeOffer ? await product.subscription?.isEligibleForIntroOffer ?? false : false
    guard !Task.isCancelled, selected == product.id else { return }
    trialEligible = eligible
  }
  private func terms(_ product: Product) -> String {
    if product.id.hasSuffix("lifetime") {
      return "A one-time purchase of \(product.displayPrice). No recurring charge."
    }
    let period = product.id.hasSuffix("yearly") ? "year" : "month"
    if trialEligible, let offer = product.subscription?.introductoryOffer,
      offer.paymentMode == .freeTrial
    {
      let unit = String(describing: offer.period.unit)
      return
        "\(offer.period.value)-\(unit) free trial, then \(product.displayPrice) per \(period). Renews automatically unless canceled at least 24 hours before the period ends. Manage or cancel in App Store settings."
    }
    return
      "\(product.displayPrice) per \(period). Renews automatically unless canceled at least 24 hours before the period ends. Manage or cancel in App Store settings."
  }
}
