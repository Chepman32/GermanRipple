import AuthenticationServices
import CryptoKit
import DeviceCheck
@preconcurrency import FirebaseAnalytics
@preconcurrency import FirebaseAppCheck
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseCrashlytics
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseRemoteConfig
import Foundation
import LearningModel
import Observation
import Security
import SyncKit

final class AppCheckFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    #if targetEnvironment(simulator)
      return AppCheckDebugProvider(app: app)
    #else
      if DCAppAttestService.shared.isSupported { return AppAttestProvider(app: app) }
      return DeviceCheckProvider(app: app)
    #endif
  }
}

@MainActor @Observable final class BackendService {
  let isConfigured: Bool
  private(set) var userID: String?
  private(set) var freeDailyChains = 3
  private(set) var peelFree = false
  private(set) var paywallEnabled = true
  private(set) var syncEnabled = true
  private(set) var contentVersion = 1
  private(set) var maintenanceMessage = ""
  private(set) var minSupportedVersion = "1.0.0"
  private(set) var schedulerWeights = SchedulerWeights()
  @ObservationIgnored private var nonce: String?
  @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
  @ObservationIgnored private var analyticsEnabled = false

  init(enabled: Bool = true) {
    if enabled, let existing = FirebaseApp.app(),
      existing.options.bundleID == Bundle.main.bundleIdentifier
    {
      isConfigured = true
    } else if enabled,
      let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let options = FirebaseOptions(contentsOfFile: path),
      options.bundleID == Bundle.main.bundleIdentifier, !options.googleAppID.isEmpty
    {
      AppCheck.setAppCheckProviderFactory(AppCheckFactory())
      FirebaseApp.configure(options: options)
      isConfigured = true
    } else {
      isConfigured = false
    }
    guard isConfigured else { return }
    if let user = Auth.auth().currentUser, !user.isAnonymous { userID = user.uid }
    authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      Task { @MainActor in self?.userID = user?.isAnonymous == false ? user?.uid : nil }
    }
  }
  func setConsent(_ enabled: Bool) {
    analyticsEnabled = enabled
    guard isConfigured else { return }
    Analytics.setConsent([
      .analyticsStorage: enabled ? .granted : .denied, .adStorage: .denied, .adUserData: .denied,
      .adPersonalization: .denied,
    ])
    Analytics.setAnalyticsCollectionEnabled(enabled)
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    if !enabled {
      Analytics.resetAnalyticsData()
      Crashlytics.crashlytics().deleteUnsentReports()
    }
  }
  func event(_ name: String, _ parameters: [String: Any] = [:]) {
    guard isConfigured, analyticsEnabled else { return }
    Analytics.logEvent(name, parameters: parameters)
  }
  func fetchConfiguration() async {
    guard isConfigured else { return }
    let config = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 12 * 3600
    config.configSettings = settings
    config.setDefaults(fromPlist: "RemoteConfigDefaults")
    do { _ = try await config.fetchAndActivate() } catch
    { /* Bundled defaults remain authoritative offline. */  }
    freeDailyChains = max(3, min(20, config["free_daily_chains"].numberValue.intValue))
    contentVersion = max(1, config["content_version_de_en"].numberValue.intValue)
    peelFree = config["peel_free"].boolValue
    paywallEnabled = config["paywall_enabled"].boolValue
    syncEnabled = config["sync_enabled"].boolValue
    maintenanceMessage = config["maintenance_message"].stringValue
    minSupportedVersion = config["min_supported_app_version"].stringValue
    if let data = config["scheduler_weights"].stringValue.data(using: .utf8),
      let weights = try? JSONDecoder().decode(SchedulerWeights.self, from: data),
      [
        weights.overdue, weights.weakness, weights.introduction, weights.overlap,
        weights.themeVariety,
      ].allSatisfy({ $0.isFinite && (0...10).contains($0) })
    {
      schedulerWeights = weights
    }
  }
  func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) throws {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw SyncError.unavailable
    }
    let nonce = bytes.map { String(format: "%02x", $0) }.joined()
    self.nonce = nonce
    request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    request.requestedScopes = []
  }
  func finishApple(_ result: Result<ASAuthorization, Error>, deletingAccount: Bool = false)
    async throws
  {
    guard isConfigured, let nonce else { throw SyncError.unavailable }
    defer { self.nonce = nil }
    let authorization = try result.get()
    guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
      let token = apple.identityToken, let tokenString = String(data: token, encoding: .utf8),
      let code = apple.authorizationCode, let codeString = String(data: code, encoding: .utf8)
    else { throw SyncError.reauthenticationRequired }
    let credential = OAuthProvider.appleCredential(
      withIDToken: tokenString, rawNonce: nonce, fullName: apple.fullName)
    if deletingAccount {
      guard let user = Auth.auth().currentUser, !user.isAnonymous else {
        throw SyncError.reauthenticationRequired
      }
      _ = try await user.reauthenticate(with: credential)
      // Revoke first; if it fails, keep the account and remote progress intact for a retry.
      try await Auth.auth().revokeToken(withAuthorizationCode: codeString)
      try await FirestoreProgressSync().deleteProgress(userID: user.uid)
      try await user.delete()
      userID = nil
    } else {
      let authResult = try await Auth.auth().signIn(with: credential)
      userID = authResult.user.uid
      let reference = Firestore.firestore().collection("users").document(authResult.user.uid)
      let existing = try await reference.getDocument()
      var fields: [String: Any] = [
        "updatedAt": FieldValue.serverTimestamp(), "uiLanguage": "en", "schemaVersion": 1,
      ]
      if !existing.exists { fields["createdAt"] = FieldValue.serverTimestamp() }
      try await reference.setData(fields, merge: true)
      event("sync_enabled")
    }
  }
  func signOut() throws {
    guard isConfigured else { return }
    try Auth.auth().signOut()
    userID = nil
  }
  func sendReport(_ report: ContentReportRecord) async throws {
    guard isConfigured else { throw SyncError.unavailable }
    var user = Auth.auth().currentUser
    if user == nil { user = try await Auth.auth().signInAnonymously().user }
    guard let user else { throw SyncError.unavailable }
    try await Firestore.firestore().collection("reports").document(report.id).setData([
      "uid": user.uid, "chainId": report.chainId, "step": report.step,
      "packVersion": report.packVersion,
      "reason": report.reason, "note": report.note, "createdAt": FieldValue.serverTimestamp(),
    ])
    event(
      "content_report", ["chain_id": report.chainId, "step": report.step, "reason": report.reason])
  }
}

/// All remote objects are decoded and bounded before they may reach local storage.
struct FirestoreProgressSync: ProgressSyncing {
  func sync(_ local: CompactProgress, userID: String) async throws -> CompactProgress {
    let local = try local.validated()
    let reference = Firestore.firestore().collection("users").document(userID).collection(
      "progress"
    ).document("de-en")
    let result = try await Firestore.firestore().runTransaction {
      transaction, errorPointer -> Any? in
      do {
        let snapshot = try transaction.getDocument(reference)
        var remote = CompactProgress()
        if var data = snapshot.data() {
          data.removeValue(forKey: "updatedAt")
          let json = try JSONSerialization.data(withJSONObject: data)
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .secondsSince1970
          if data["schemaVersion"] as? Int == 1 {
            remote = try CompactProgress.migrating(
              decoder.decode(ProgressSnapshot.self, from: json).validated())
          } else {
            remote = try decoder.decode(CompactProgress.self, from: json).validated()
          }
        }
        let merged = try CompactProgress.merge(local, remote)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let bytes = try encoder.encode(merged)
        guard bytes.count < 800_000 else { throw SyncError.documentTooLarge }
        var data = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] ?? [:]
        data["updatedAt"] = FieldValue.serverTimestamp()
        transaction.setData(data, forDocument: reference)
        return bytes
      } catch {
        errorPointer?.pointee = error as NSError
        return nil
      }
    }
    guard let data = result as? Data else { throw SyncError.invalidData }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return try decoder.decode(CompactProgress.self, from: data).validated()
  }
  func deleteProgress(userID: String) async throws {
    let user = Firestore.firestore().collection("users").document(userID)
    // This build only supports de-en. Delete subdocuments before the account document.
    let batch = Firestore.firestore().batch()
    batch.deleteDocument(user.collection("progress").document("de-en"))
    batch.deleteDocument(user)
    try await batch.commit()
  }
}
