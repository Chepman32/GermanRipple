import ContentKit
import SwiftData
import SwiftUI

@main struct RippleApp: App {
  @State private var store: AppStore?
  @State private var launchError: String?
  @Environment(\.scenePhase) private var scenePhase
  init() {
    do {
      #if DEBUG
        let inMemory = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let cloudEnabled = !inMemory
          && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
          && NSClassFromString("XCTestCase") == nil
        let defaults = inMemory ? UserDefaults(suiteName: "app.ripple.uitesting")! : .standard
        if inMemory { defaults.removePersistentDomain(forName: "app.ripple.uitesting") }
      #else
        let inMemory = false
        let cloudEnabled = true
        let defaults = UserDefaults.standard
      #endif
      let container = try Persistence.container(inMemory: inMemory)
      guard let url = Bundle.main.url(forResource: "baseline", withExtension: "json") else {
        throw ContentError.invalid("Bundled lessons are missing")
      }
      let pack = try ContentPack.decode(Data(contentsOf: url))
      let settings = AppSettings(defaults: defaults)
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") {
          settings.onboardingComplete = true
          settings.consentAsked = true
        }
        if inMemory {
          settings.autoplay = false
          settings.sounds = false
        }
      #endif
      let applicationStore = try AppStore(
        container: container, pack: pack, settings: settings, cloudEnabled: cloudEnabled)
      #if DEBUG
        if inMemory,
          let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--chain=") }
          )
        {
          applicationStore.startTestingChain(String(argument.dropFirst(8)))
        }
      #endif
      _store = State(initialValue: applicationStore)
    } catch {
      _launchError = State(
        initialValue:
          "Ripple couldn’t open your lessons or saved progress. Close and reopen the app to try again. Your saved data has not been reset."
      )
    }
  }
  var body: some Scene {
    WindowGroup {
      Group {
        if let store {
          RootView().environment(store).task { await store.start() }
        } else {
          EmptyState(
            symbol: "exclamationmark.circle", title: "Couldn’t open Ripple",
            message: launchError ?? "Please reopen the app.")
        }
      }.tint(Palette.accent)
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            Task { await store?.foreground() }
          } else if phase == .background {
            store?.audio.stop()
            Task { await store?.syncProgress() }
          }
        }
    }
  }
}

struct RootView: View {
  @Environment(AppStore.self) private var store
  @State private var consent = false
  var body: some View {
    @Bindable var store = store
    Group {
      if store.settings.onboardingComplete {
        TabView(selection: $store.selectedTab) {
          NavigationStack { TodayView() }.tabItem {
            Label("Today", systemImage: "circle.dotted.circle.fill")
          }.tag(0)
          NavigationStack { RulesView() }.tabItem {
            Label("Rules", systemImage: "square.grid.2x2.fill")
          }.tag(1)
          NavigationStack { GalleryView() }.tabItem {
            Label("Gallery", systemImage: "rectangle.stack.fill")
          }.tag(2)
          NavigationStack { SettingsView() }.tabItem {
            Label("Settings", systemImage: "slider.horizontal.3")
          }.tag(3)
        }
      } else {
        OnboardingView()
      }
    }
    .fullScreenCover(isPresented: $store.showPractice) { PracticeView() }
    .sheet(
      isPresented: Binding(
        get: { store.showPaywall && !store.showPractice }, set: { store.showPaywall = $0 })
    ) { PaywallView() }
    .sheet(isPresented: $consent, onDismiss: { store.settings.consentAsked = true }) {
      ConsentView()
    }
    .alert(
      "Something needs attention",
      isPresented: Binding(
        get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    ) {
      Button("Close", role: .cancel) { store.errorMessage = nil }
    } message: {
      Text(store.errorMessage ?? "")
    }
    .onAppear { consent = store.settings.onboardingComplete && !store.settings.consentAsked }
    .onChange(of: store.settings.onboardingComplete) { _, done in
      if done && !store.settings.consentAsked { consent = true }
    }
  }
}
