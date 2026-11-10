import AuthenticationServices
import RippleEngine
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(AppStore.self) private var store
  @State private var exporting = false
  @State private var exportDocument = ProgressDocument(data: Data())
  @State private var reset = false
  @State private var deleteAccount = false
  var body: some View {
    @Bindable var settings = store.settings
    Form {
      Section("Learning") {
        Toggle("Always guided", isOn: $settings.alwaysGuided)
        Toggle("Hide translation until solved", isOn: $settings.hideTranslation)
        Picker("Daily goal", selection: $settings.dailyGoal) {
          ForEach([3, 6, 9], id: \.self) { Text("\($0) chains").tag($0) }
        }
        Picker("Practice level", selection: $settings.band) {
          ForEach(CEFR.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.onChange(of: settings.band) { _, _ in store.refreshToday() }
        Button("Try the interactive demo") { store.startDemo() }
      }
      Section("Audio") {
        Toggle("Play after each correct step", isOn: $settings.autoplay)
        Picker("Speech rate", selection: $settings.slowSpeech) {
          Text("Normal · 1×").tag(false)
          Text("Slower · 0.8×").tag(true)
        }
        Picker("German voice", selection: $settings.voiceID) {
          Text("Automatic").tag("")
          ForEach(AudioService.germanVoices, id: \.identifier) { voice in
            Text(voice.name).tag(voice.identifier)
          }
        }
        Text(
          "Automatic uses a saved lesson recording when available, with an installed voice as fallback. Selecting an installed voice always uses that voice offline. Find more voices in iOS Settings → Accessibility → Spoken Content → Voices."
        ).font(.caption).foregroundStyle(Palette.secondary)
        Button("Preview voice", systemImage: "speaker.wave.2") {
          store.audio.speak(
            text: "Mit jedem kleinen Schritt wird dein Deutsch ein bisschen besser.",
            settings: settings)
        }
      }
      Section("Feedback") {
        Toggle("Haptics", isOn: $settings.haptics)
        Toggle("Sounds", isOn: $settings.sounds)
      }
      Section("Notifications") { NavigationLink("Daily reminder") { ReminderSettingsView() } }
      Section {
        if store.backend.userID != nil {
          Label("Signed in with Apple", systemImage: "checkmark.icloud")
          if let message = store.syncMessage {
            Text(message).font(.caption).foregroundStyle(Palette.secondary)
          }
          Button(store.syncing ? "Syncing…" : "Sync now") {
            Task { await store.syncProgress(force: true) }
          }.disabled(store.syncing)
          Button("Sign Out") {
            do { try store.backend.signOut() } catch {
              store.errorMessage = "Couldn’t sign out. Please try again."
            }
          }
          Button("Delete Account", role: .destructive) { deleteAccount = true }
        } else {
          if store.backend.isConfigured {
            SignInWithAppleButton(
              .signIn,
              onRequest: { request in
                do { try store.backend.prepareAppleRequest(request) } catch {
                  store.errorMessage = "Apple sign-in couldn’t be prepared. Please try again."
                }
              }, onCompletion: { result in Task { await signIn(result) } }
            )
            .signInWithAppleButtonStyle(.black).frame(height: 50).clipShape(
              RoundedRectangle(cornerRadius: 10))
          } else {
            Label("Progress stays on this device", systemImage: "iphone")
          }
        }
      } header: {
        Text("Account & Sync")
      } footer: {
        Text(
          store.backend.isConfigured
            ? "An account is optional. Sign in to merge your learning progress across devices. Your lesson history stays on this device."
            : "Cloud sync isn’t available in this build. All lessons and progress work on this device, without an account."
        )
      }
      Section("Ripple Pro") {
        HStack {
          Text("Your plan")
          Spacer()
          Text(store.purchases.isPro ? "Pro" : "Free").foregroundStyle(Palette.accent)
        }
        if !store.purchases.isPro {
          Button("Explore Ripple Pro") { store.openPaywall("settings") }
            .accessibilityIdentifier("settings.pro")
        }
        Button("Restore Purchases") { Task { await store.purchases.restore() } }.disabled(
          store.purchases.isPurchasing)
        Button("Manage Subscription") { Task { await manageSubscription() } }
        if let message = store.purchases.message {
          Text(message).font(.caption).foregroundStyle(Palette.secondary)
        }
      }
      Section {
        Toggle("Share analytics & crash reports", isOn: $settings.analytics).onChange(
          of: settings.analytics
        ) { _, enabled in store.backend.setConsent(enabled) }
        NavigationLink("Privacy Policy") { PrivacyView() }
        Button("Export My Data", systemImage: "square.and.arrow.up") {
          do {
            exportDocument = ProgressDocument(data: try store.exportData())
            exporting = true
          } catch { store.errorMessage = "Your progress couldn’t be exported. Please try again." }
        }
        NavigationLink("Content Report History") { ReportHistoryView() }
        Button("Reset Progress on This Device", role: .destructive) { reset = true }
      } header: {
        Text("Privacy & Data")
      } footer: {
        Text("Your JSON export includes learning history and content reports.")
      }
      Section("About") {
        LabeledContent("App version", value: "1.0.0 (1)")
        LabeledContent("German pack", value: "Version \(store.pack.version)")
        LabeledContent(
          "Lesson library",
          value: "\(store.pack.chains.count) chains · \(store.pack.rules.count) rules")
        NavigationLink("Licenses & Attributions") { LicenseView() }
        if let url = AppLinks.support { Link("Support", destination: url) }
      }
    }.navigationTitle("Settings")
      .confirmationDialog(
        "Reset progress on this device?", isPresented: $reset, titleVisibility: .visible
      ) {
        Button("Reset This Device", role: .destructive) { store.resetProgress() }
      } message: {
        Text(
          "Your sentences, mastery and local lesson history will be removed. You’ll be signed out; your cloud account and purchases are kept."
        )
      }
      .sheet(isPresented: $deleteAccount) { DeleteAccountView() }
      .fileExporter(
        isPresented: $exporting, document: exportDocument, contentType: .json,
        defaultFilename: "Ripple-progress"
      ) { result in
        if case .failure = result {
          store.errorMessage = "The export wasn’t saved. You can try again."
        }
      }
  }
  private func signIn(_ result: Result<ASAuthorization, Error>) async {
    do {
      try await store.backend.finishApple(result)
      await store.syncProgress(force: true)
    } catch {
      if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
        store.errorMessage =
          "Apple sign-in couldn’t be completed. Check your connection and try again."
      }
    }
  }
  private func manageSubscription() async {
    guard
      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
    else { return }
    do { try await StoreKit.AppStore.showManageSubscriptions(in: scene) } catch {
      store.errorMessage =
        "Subscription settings couldn’t be opened. You can manage them in the App Store."
    }
  }
}

struct ProgressDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.json]
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

struct ReminderSettingsView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var time = Date.now
  @State private var status: String?
  var body: some View {
    @Bindable var settings = store.settings
    Form {
      Section {
        Toggle("Daily reminder", isOn: $settings.reminderEnabled).onChange(
          of: settings.reminderEnabled
        ) { _, _ in Task { await update() } }
        .disabled(settings.completedSessions == 0)
        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute).disabled(
          !settings.reminderEnabled
        ).onChange(of: time) { _, _ in Task { await update() } }
      } footer: {
        Text(
          settings.completedSessions == 0
            ? "Finish your first session before setting a reminder."
            : "One gentle reminder each day. No streak warnings, and no notifications when this is off."
        )
      }
      if let status {
        Section {
          Text(status).font(.subheadline)
          Link("Open iOS Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
        }
      }
    }.navigationTitle("Daily Reminder").toolbar {
      ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
    }
    .onAppear {
      time =
        Calendar.current.date(
          bySettingHour: settings.reminderHour, minute: settings.reminderMinute, second: 0, of: .now
        ) ?? .now
    }
  }
  private func update() async {
    let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
    store.settings.reminderHour = parts.hour ?? 19
    store.settings.reminderMinute = parts.minute ?? 0
    do {
      let allowed = try await ReminderService.update(
        enabled: store.settings.reminderEnabled, hour: store.settings.reminderHour,
        minute: store.settings.reminderMinute, requestPermission: true)
      if store.settings.reminderEnabled && !allowed {
        store.settings.reminderEnabled = false
        status = "Notifications are off for Ripple. You can allow them in iOS Settings."
      }
      store.settings.reminderAsked = true
    } catch { status = "The reminder couldn’t be scheduled. Please try again." }
  }
}

private struct DeleteAccountView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var busy = false
  @State private var message: String?
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: "person.crop.circle.badge.minus").font(.largeTitle).foregroundStyle(
          Palette.wrong)
        Text("Delete your account").font(.title.weight(.semibold))
        Text(
          "This permanently deletes your cloud progress and account, and revokes Ripple’s Apple sign-in access. Your progress on this device is kept. Purchases remain with your Apple Account."
        ).foregroundStyle(Palette.secondary)
        Text("Sign in with Apple again to confirm which account to delete.").font(.subheadline)
        SignInWithAppleButton(
          .continue,
          onRequest: { request in
            do { try store.backend.prepareAppleRequest(request) } catch {
              message = "Couldn’t prepare Apple sign-in."
            }
          },
          onCompletion: { result in
            Task {
              busy = true
              defer { busy = false }
              do {
                try await store.backend.finishApple(result, deletingAccount: true)
                dismiss()
              } catch {
                message =
                  "The account couldn’t be deleted. Check your connection, then sign in and try again."
              }
            }
          }
        )
        .signInWithAppleButtonStyle(.black).frame(height: 50).disabled(busy)
        if busy { ProgressView() }
        if let message { Text(message).font(.subheadline).foregroundStyle(Palette.wrong) }
        Spacer()
      }.padding(24).navigationTitle("Account").navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.disabled(busy)
        }
      }
    }.interactiveDismissDisabled(busy)
  }
}

enum AppLinks {
  static func configured(_ key: String) -> URL? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
      let url = URL(string: value), url.scheme == "https"
    else { return nil }
    return url
  }
  static var privacy: URL? { configured("RipplePrivacyURL") }
  static var support: URL? { configured("RippleSupportURL") }
}

struct PrivacyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("Your learning stays yours.").font(.system(.title, design: .serif, weight: .medium))
        paragraph(
          "Learn without an account",
          "Your sentences, rule mastery, practice history and settings are saved on this device. Lessons and speech work offline. There is no runtime AI, and your microphone is never used."
        )
        paragraph(
          "Optional cloud sync",
          "If you choose Sign in with Apple, your learning progress is merged with a private record in Firebase. Apple supplies an account identifier. Your progress is visible only to your signed-in account. Detailed step history stays on your device."
        )
        paragraph(
          "Analytics and crash reports",
          "These are off until you opt in. If enabled, Firebase receives product events such as lesson IDs, attempts and hint levels, plus crash diagnostics. Ripple does not request an advertising identifier or use cross-app tracking. Turn this off anytime in Settings."
        )
        paragraph(
          "Reports and purchases",
          "Sending a content report shares the lesson, step, reason and any note you enter. A saved report may remain only on this device if it cannot be sent. Apple processes purchases; Ripple verifies signed transactions on your device."
        )
        paragraph(
          "Your controls",
          "Export your learning history and content reports as JSON, reset this device, or delete your cloud account in Settings. Account deletion revokes Apple sign-in access and removes your cloud progress. Resetting local data is a separate choice."
        )
        paragraph(
          "Reminders",
          "Reminders are local, optional and limited to one a day. Ripple does not send remote push notifications."
        )
        if let url = AppLinks.privacy { Link("Full Privacy Policy", destination: url) }
        if let url = AppLinks.support { Link("Contact Support", destination: url) }
      }.padding(24).readingWidth()
    }.background(Palette.paper).navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
  }
  private func paragraph(_ title: String, _ text: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      Text(text).foregroundStyle(Palette.secondary).lineSpacing(4)
    }
  }
}

struct ConsentView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        RippleMark(size: 70)
        Text("Help improve Ripple?").font(.system(.title, design: .serif, weight: .medium))
        Text(
          "Optional analytics and crash reports help find difficult lessons and fix problems. They include lesson activity and diagnostics. No advertising identifier, microphone, or cross-app tracking."
        ).foregroundStyle(Palette.secondary).lineSpacing(4)
        Text("Your choice won’t affect your lessons. Change it anytime in Settings.").font(
          .subheadline
        ).foregroundStyle(Palette.secondary)
        Spacer()
        PrimaryButton("Allow analytics & crash reports") { choose(true) }
        Button("Keep them off") { choose(false) }.frame(maxWidth: .infinity, minHeight: 48)
          .accessibilityIdentifier("consent.decline")
        NavigationLink("Read about privacy") { PrivacyView() }.font(.caption).frame(
          maxWidth: .infinity, minHeight: 44)
      }.padding(28)
    }.presentationDetents([.large])
  }
  private func choose(_ enabled: Bool) {
    store.settings.analytics = enabled
    store.settings.consentAsked = true
    store.backend.setConsent(enabled)
    dismiss()
  }
}

private struct LicenseView: View {
  var body: some View {
    List {
      Section("Ripple") {
        Text(
          "Lesson text, rule explainers and visual design were authored for Ripple. No external morphology dataset is bundled."
        )
      }
      Section("Firebase Apple SDK") {
        Text(
          "Copyright Google LLC. Apache License 2.0. Dependency licenses and privacy manifests are included by Swift Package Manager."
        )
        Link(
          "Firebase license",
          destination: URL(
            string: "https://github.com/firebase/firebase-ios-sdk/blob/main/LICENSE")!)
      }
      Section("Apple frameworks") {
        Text(
          "Speech uses installed iOS voices. System icons use SF Symbols under Apple’s platform terms."
        )
      }
    }.navigationTitle("Attributions")
  }
}
