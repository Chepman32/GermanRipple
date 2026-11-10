import ContentKit
import RippleEngine
import StoreKitTest
import SwiftData
import SyncKit
import XCTest

@testable import Ripple

@MainActor final class AppTests: XCTestCase {
  func testAtomicCompletionAndCheckpointResume() throws {
    let container = try Persistence.container(inMemory: true)
    let url = try XCTUnwrap(Bundle.main.url(forResource: "baseline", withExtension: "json"))
    let pack = try ContentPack.decode(Data(contentsOf: url))
    let settings = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    let store = try Ripple.AppStore(
      container: container, pack: pack, settings: settings, cloudEnabled: false)
    XCTAssertFalse(store.backend.isConfigured)
    store.startToday()
    let count = try XCTUnwrap(store.session?.current.steps.count)
    for _ in 0..<count {
      let step = try XCTUnwrap(store.session?.player.step)
      store.mutate { p in
        p.apply()
        for token in step.tokens { p.choose(tokenID: token.id, form: token.text) }
        for (i, token) in step.tokens.enumerated() { p.move(tokenID: token.id, to: i) }
        p.check()
      }
      store.nextStep()
    }
    XCTAssertEqual(store.completions.count, 1)
    XCTAssertEqual(try store.cloudSnapshot().completedCount, 1)
    XCTAssertEqual(store.todayCount, 1)
    XCTAssertEqual(store.session?.phase, .chainSummary)
    let restored = try Ripple.AppStore(
      container: container, pack: pack, settings: settings, cloudEnabled: false)
    XCTAssertEqual(restored.session?.phase, .chainSummary)
    restored.nextStep()
    XCTAssertEqual(restored.completions.count, 1)
    XCTAssertEqual(try restored.cloudSnapshot().completedCount, 1)
    XCTAssertNoThrow(try restored.exportData())
  }
  func testLocalResetKeepsPurchasesAndClearsLearning() throws {
    let container = try Persistence.container(inMemory: true)
    let url = try XCTUnwrap(Bundle.main.url(forResource: "baseline", withExtension: "json"))
    let pack = try ContentPack.decode(Data(contentsOf: url))
    let store = try Ripple.AppStore(container: container, pack: pack, cloudEnabled: false)
    let oldReplica = try XCTUnwrap(store.context.fetch(FetchDescriptor<CloudProgressRecord>()).first?.replicaID)
    store.startToday()
    XCTAssertNotNil(store.session)
    store.resetProgress()
    XCTAssertNil(store.session)
    XCTAssertEqual(store.todayCount, 0)
    XCTAssertTrue(store.completions.isEmpty)
    XCTAssertEqual(try store.cloudSnapshot().completedCount, 0)
    let newReplica = try XCTUnwrap(store.context.fetch(FetchDescriptor<CloudProgressRecord>()).first?.replicaID)
    XCTAssertNotEqual(oldReplica, newReplica)
  }
  func testSyncImportAndReplayKeepCountersAndVocabularyExact() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "baseline", withExtension: "json"))
    let pack = try ContentPack.decode(Data(contentsOf: url))
    let a = try Ripple.AppStore(container: Persistence.container(inMemory: true), pack: pack, cloudEnabled: false)
    let b = try Ripple.AppStore(container: Persistence.container(inMemory: true), pack: pack, cloudEnabled: false)
    a.startToday()
    try finishCurrentChain(in: a)
    let first = try a.cloudSnapshot()
    try b.importCloudProgress(first)
    XCTAssertEqual(try b.cloudSnapshot().completedCount, 1)
    XCTAssertEqual(b.vocabulary, a.vocabulary)
    try b.importCloudProgress(first)
    XCTAssertEqual(b.vocabulary, a.vocabulary)
    b.startToday()
    try finishCurrentChain(in: b)
    XCTAssertEqual(try b.cloudSnapshot().completedCount, 2)
    try a.importCloudProgress(b.cloudSnapshot())
    XCTAssertEqual(try a.cloudSnapshot().completedCount, 2)
    XCTAssertEqual(a.vocabulary, b.vocabulary)
    try b.importCloudProgress(a.cloudSnapshot())
    XCTAssertEqual(try b.cloudSnapshot().completedCount, 2)
    XCTAssertEqual(a.vocabulary, b.vocabulary)
  }
  func testExistingStoreMigratesWithoutLosingDetailedHistory() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let location = directory.appendingPathComponent("progress.store")
    let oldSchema = Schema([
      RuleStateRecord.self, ChainRecord.self, StepAttemptRecord.self, StreakDay.self,
      PackState.self, ContentReportRecord.self, SessionCheckpoint.self, VocabularyExposureRecord.self,
    ])
    try autoreleasepool {
      let old = try ModelContainer(for: oldSchema, configurations:
        ModelConfiguration(schema: oldSchema, url: location, cloudKitDatabase: .none))
      let context = ModelContext(old)
      for second in 1...2 {
        context.insert(ChainRecord(.init(chainID: "de.a1.read.000",
          completedAt: Date(timeIntervalSince1970: Double(second)), mode: "forward",
          firstTryRate: 1, durationSeconds: 90)))
      }
      try context.save()
    }
    let current = try ModelContainer(for: Persistence.schema, configurations:
      ModelConfiguration(schema: Persistence.schema, url: location, cloudKitDatabase: .none))
    let url = try XCTUnwrap(Bundle.main.url(forResource: "baseline", withExtension: "json"))
    let store = try Ripple.AppStore(container: current, pack: ContentPack.decode(Data(contentsOf: url)), cloudEnabled: false)
    XCTAssertEqual(store.completions.count, 2)
    XCTAssertEqual(try store.cloudSnapshot().completedCount, 2)
    XCTAssertEqual(try store.cloudSnapshot().chains.count, 1)
    let restarted = try Ripple.AppStore(container: current, pack: store.pack, cloudEnabled: false)
    XCTAssertEqual(try restarted.cloudSnapshot().completedCount, 2)
  }
  private func finishCurrentChain(in store: Ripple.AppStore) throws {
    let count = try XCTUnwrap(store.session?.current.steps.count)
    for _ in 0..<count {
      let step = try XCTUnwrap(store.session?.player.step)
      store.mutate { player in
        player.apply()
        for token in step.tokens { player.choose(tokenID: token.id, form: token.text) }
        for (index, token) in step.tokens.enumerated() { player.move(tokenID: token.id, to: index) }
        player.check()
      }
      store.nextStep()
    }
    XCTAssertEqual(store.session?.phase, .chainSummary)
  }
  func testExpiredAttemptsAreRemovedOnOpenAndExportContainsRecentHistoryAndReports() throws {
    let container = try Persistence.container(inMemory: true)
    let context = ModelContext(container)
    let result = try JSONDecoder().decode(StepResult.self, from: Data(
      #"{"index":0,"hintLevel":1,"attempts":1,"revealed":false,"ruleIDs":["verb.present.regular"],"failedRuleIDs":[]}"#.utf8))
    context.insert(StepAttemptRecord(chainID: "expired", result: result,
      at: .now.addingTimeInterval(-91 * 86_400), completionKey: "expired"))
    context.insert(StepAttemptRecord(chainID: "recent", result: result,
      at: .now.addingTimeInterval(-86_400), completionKey: "recent"))
    context.insert(ContentReportRecord(chainId: "de.a1.read.000", step: 0, packVersion: 1,
      reason: "bad_translation", note: "Please check this translation."))
    try context.save()
    let url = try XCTUnwrap(Bundle.main.url(forResource: "baseline", withExtension: "json"))
    let store = try Ripple.AppStore(container: container, pack: ContentPack.decode(Data(contentsOf: url)), cloudEnabled: false)
    XCTAssertEqual(store.history.map(\.chainId), ["recent"])
    XCTAssertEqual(try store.context.fetch(FetchDescriptor<StepAttemptRecord>()).count, 1)
    let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: store.exportData()) as? [String: Any])
    let attempts = try XCTUnwrap(exported["attemptHistory"] as? [[String: Any]])
    XCTAssertEqual(attempts.count, 1)
    XCTAssertEqual(attempts.first?["chainId"] as? String, "recent")
    let reports = try XCTUnwrap(exported["contentReports"] as? [[String: Any]])
    XCTAssertEqual(reports.first?["note"] as? String, "Please check this translation.")
  }
  func testVerifiedLifetimePurchaseAndRevocation() async throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "Ripple", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: url)
    session.disableDialogs = true
    session.clearTransactions()
    let service = PurchaseService()
    await service.start()
    await service.loadProducts()
    XCTAssertEqual(service.products.count, 3)
    let product = try XCTUnwrap(service.products.first { $0.id == "app.ripple.pro.lifetime" })
    await service.purchase(product)
    await waitForEntitlement(service, expected: true)
    XCTAssertTrue(service.isPro)
    let transaction = try XCTUnwrap(session.allTransactions().first)
    try session.refundTransaction(identifier: transaction.identifier)
    await waitForEntitlement(service, expected: false)
    XCTAssertFalse(service.isPro)
  }
  func testSubscriptionExpirationRevokesPro() async throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "Ripple", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: url)
    session.disableDialogs = true
    session.clearTransactions()
    let service = PurchaseService()
    await service.start()
    await service.loadProducts()
    let product = try XCTUnwrap(service.products.first { $0.id == "app.ripple.pro.monthly" })
    await service.purchase(product)
    await waitForEntitlement(service, expected: true)
    XCTAssertTrue(service.isPro)
    try session.expireSubscription(productIdentifier: product.id)
    await waitForEntitlement(service, expected: false)
    XCTAssertFalse(service.isPro)
  }
  func testPendingPurchaseGrantsNothingUntilApproved() async throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "Ripple", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: url)
    session.disableDialogs = true
    session.clearTransactions()
    session.askToBuyEnabled = true
    defer { session.askToBuyEnabled = false }
    let service = PurchaseService()
    await service.start()
    await service.loadProducts()
    let product = try XCTUnwrap(service.products.first { $0.id == "app.ripple.pro.lifetime" })
    await service.purchase(product)
    XCTAssertFalse(service.isPro)
    XCTAssertTrue(service.message?.contains("awaiting approval") ?? false)
    let transaction = try XCTUnwrap(session.allTransactions().first)
    try session.approveAskToBuyTransaction(identifier: transaction.identifier)
    await waitForEntitlement(service, expected: true)
    XCTAssertTrue(service.isPro)
  }
  private func waitForEntitlement(_ service: PurchaseService, expected: Bool) async {
    for _ in 0..<80 {
      await service.refreshEntitlements()
      if service.isPro == expected { return }
      try? await Task.sleep(for: .milliseconds(100))
    }
  }
}
