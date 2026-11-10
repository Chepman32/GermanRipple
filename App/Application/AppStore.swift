import ContentKit
import Foundation
import LearningModel
import Observation
import RippleEngine
import SwiftData
import SyncKit

enum PracticeMode: String, Codable { case forward, peel, demo, placement }
enum SessionPhase: String, Codable { case playing, chainSummary, sessionSummary }

struct PracticeSession: Codable {
  var queue: [Chain]
  var position: Int = 0
  var player: ChainPlayer
  var mode: PracticeMode
  var phase: SessionPhase = .playing
  var startedAt: Date = .now
  var stepStartedAt: Date = .now
  var committed: Set<Int> = []
  var initialStrengths: [String: Double]
  var placementResults: [StepResult] = []
  var placementBands: [CEFR] = []
  var current: Chain { queue[position] }
  init(queue: [Chain], mode: PracticeMode, hint: HintLevel, strengths: [String: Double]) {
    self.queue = queue
    self.mode = mode
    player = ChainPlayer(chain: queue[0], hintLevel: hint)
    initialStrengths = strengths
  }
}

@MainActor @Observable final class AppStore {
  let settings: AppSettings
  let purchases = PurchaseService()
  let backend: BackendService
  let audio: AudioService
  private(set) var pack: ContentPack
  private(set) var rules: [String: RuleState] = [:]
  private(set) var completions: [ChainRecord] = []
  private(set) var history: [StepAttemptRecord] = []
  private(set) var days: [String: Int] = [:]
  private(set) var reports: [ContentReportRecord] = []
  private(set) var vocabulary: [String: Int] = [:]
  private(set) var session: PracticeSession?
  private(set) var todayChains: [Chain] = []
  var showPractice = false
  var showPaywall = false
  var paywallTrigger = "settings"
  var selectedTab = 0
  var onboardingPage = 0
  var errorMessage: String?
  var syncMessage: String?
  var syncing = false
  var updateRequiresApp = false
  @ObservationIgnored let context: ModelContext
  @ObservationIgnored private let updater: ContentUpdater?
  @ObservationIgnored private var dayKey = ""
  @ObservationIgnored private var started = false
  @ObservationIgnored private var refreshing = false

  init(
    container: ModelContainer, pack: ContentPack, settings: AppSettings = AppSettings(),
    cloudEnabled: Bool = true
  ) throws {
    self.settings = settings
    audio = AudioService(recordingDownloadsEnabled: cloudEnabled)
    backend = BackendService(enabled: cloudEnabled)
    self.pack = pack
    context = ModelContext(container)
    context.autosaveEnabled = false
    if cloudEnabled,
      let string = Bundle.main.object(forInfoDictionaryKey: "RippleContentBaseURL") as? String,
      let url = URL(string: string), url.scheme == "https"
    {
      let root = URL.applicationSupportDirectory.appendingPathComponent(
        "Content", isDirectory: true)
      updater = ContentUpdater(root: root, baseURL: url)
    } else {
      updater = nil
    }
    try purgeAttemptHistory()
    try reload()
    _ = try cloudRecord()
    try context.save()
    if let data = try context.fetch(FetchDescriptor<SessionCheckpoint>()).first?.data {
      session = try? JSONDecoder().decode(PracticeSession.self, from: data)
    }
    refreshToday()
  }
  var todayCount: Int { days[PracticeDay.key(.now)] ?? 0 }
  var streak: Int { PracticeDay.streak(days: days, now: .now).count }
  var longestSentence: Int {
    completions.compactMap { record in record.chain ?? pack.chains.first { $0.id == record.chainId }
    }.map { Sentence.wordCount($0.final.tokens) }.max() ?? 0
  }
  var canPeel: Bool { purchases.isPro || backend.peelFree || !backend.paywallEnabled }
  var dailyLimitReached: Bool {
    !purchases.isPro && backend.paywallEnabled && todayCount >= backend.freeDailyChains
      && settings.completedSessions > 0
  }
  var hasResume: Bool { session?.mode == .forward || session?.mode == .peel }

  func start() async {
    guard !started else { return }
    started = true
    backend.setConsent(settings.analytics)
    if let updater, let installed = try? await updater.installed(), installed.version > pack.version
    {
      pack = installed
      refreshToday()
    }
    await purchases.start()
    await foreground()
  }
  func foreground() async {
    guard !refreshing else { return }
    refreshing = true
    defer { refreshing = false }
    do {
      try purgeAttemptHistory()
      try context.save()
      try reload()
    } catch {
      context.rollback()
      errorMessage = "Older practice history couldn’t be removed yet. Please try opening Ripple again."
    }
    if dayKey != PracticeDay.key(.now) { refreshToday() }
    await backend.fetchConfiguration()
    updateRequiresApp =
      backend.minSupportedVersion.compare("1.0.0", options: .numeric) == .orderedDescending
    await checkForContentUpdate()
    await syncProgress()
  }
  private func reload() throws {
    rules = Dictionary(
      try context.fetch(FetchDescriptor<RuleStateRecord>()).map { ($0.ruleId, $0.value) },
      uniquingKeysWith: { _, last in last })
    UnlockGraph.refresh(rules: pack.rules, states: &rules, now: .now)
    completions = try context.fetch(
      FetchDescriptor<ChainRecord>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)]))
    history = try context.fetch(FetchDescriptor<StepAttemptRecord>(sortBy: [SortDescriptor(\.at)]))
    days = Dictionary(
      try context.fetch(FetchDescriptor<StreakDay>()).map { ($0.day, $0.chainsCompleted) },
      uniquingKeysWith: max)
    reports = try context.fetch(
      FetchDescriptor<ContentReportRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    vocabulary = Dictionary(
      try context.fetch(FetchDescriptor<VocabularyExposureRecord>()).map { ($0.lemma, $0.count) },
      uniquingKeysWith: max)
  }
  private func purgeAttemptHistory() throws {
    let cutoff = Date.now.addingTimeInterval(-90 * 86_400)
    try context.delete(model: StepAttemptRecord.self, where: #Predicate { $0.at < cutoff })
  }
  func refreshToday() {
    dayKey = PracticeDay.key(.now)
    let allHistory = completions.filter { $0.mode == "forward" }.map {
      ChainHistory(chainID: $0.chainId, completedAt: $0.completedAt)
    }
    todayChains = Scheduler(weights: backend.schedulerWeights).select(
      chains: pack.chains, rules: pack.rules, states: rules, history: allHistory,
      band: settings.band, now: .now)
  }
  func startToday() {
    if hasResume {
      showPractice = true
      return
    }
    if dailyLimitReached {
      openPaywall("daily_limit")
      return
    }
    refreshToday()
    let remaining =
      purchases.isPro || !backend.paywallEnabled || settings.completedSessions == 0
      ? 3 : max(1, backend.freeDailyChains - todayCount)
    begin(Array(todayChains.prefix(remaining)), mode: .forward)
  }
  func practice(rule: Rule) {
    let key = "focusedPracticeDay"
    if !purchases.isPro && backend.paywallEnabled
      && UserDefaults.standard.string(forKey: key) == PracticeDay.key(.now)
    {
      openPaywall("rule_practice")
      return
    }
    if dailyLimitReached {
      openPaywall("daily_limit")
      return
    }
    let selected = Scheduler().select(
      chains: pack.chains, rules: pack.rules, states: rules, history: [], band: settings.band,
      now: .now, count: 2, focusing: rule.id)
    guard !selected.isEmpty else {
      errorMessage = "Keep practicing Today to unlock this rule’s prerequisites."
      return
    }
    UserDefaults.standard.set(PracticeDay.key(.now), forKey: key)
    begin(
      Array(
        selected.prefix(purchases.isPro ? 2 : min(2, max(1, backend.freeDailyChains - todayCount)))),
      mode: .forward)
  }
  func peel(_ chain: Chain) {
    guard canPeel else {
      openPaywall("peel")
      return
    }
    begin([Peel.derive(chain)], mode: .peel)
  }
  func startDemo() { begin([DemoContent.chain], mode: .demo) }
  #if DEBUG
    func startTestingChain(_ id: String) {
      if let chain = pack.chains.first(where: { $0.id == id }) { begin([chain], mode: .forward) }
    }
  #endif
  func startPlacement() {
    let choices = ["de.a1.visit.000", "de.a2.cafe.000", "de.b1.relative.000"].compactMap {
      id -> Chain? in
      guard var chain = pack.chains.first(where: { $0.id == id }) else { return nil }
      chain.steps = Array(chain.steps.prefix(4))
      return chain
    }
    begin(choices, mode: .placement)
  }
  private func begin(_ queue: [Chain], mode: PracticeMode) {
    guard !queue.isEmpty else {
      errorMessage = "No lessons are available for this selection."
      return
    }
    audio.stop()
    let hint =
      mode == .placement
      ? HintLevel.free
      : mode == .demo
        ? .guided
        : UnlockGraph.hintLevel(
          for: queue[0].steps[0], states: rules, alwaysGuided: settings.alwaysGuided)
    session = PracticeSession(
      queue: queue, mode: mode, hint: hint, strengths: rules.mapValues(\.strength))
    persistCheckpoint()
    showPractice = true
    backend.event("session_start", ["chains_planned": queue.count])
    backend.event(
      "chain_start", ["chain_id": queue[0].id, "mode": mode.rawValue, "pack_version": pack.version])
  }
  func mutate(_ action: (inout ChainPlayer) -> Void) {
    guard var session, session.phase == .playing else { return }
    action(&session.player)
    self.session = session
    persistCheckpoint()
  }
  func nextStep() {
    guard var session, session.player.state.phase.isFinished else { return }
    let index = session.player.index
    let next = index + 1 < session.current.steps.count ? session.current.steps[index + 1] : nil
    let hint =
      session.mode == .placement
      ? HintLevel.free
      : session.mode == .demo
        ? .guided
        : next.map {
          UnlockGraph.hintLevel(for: $0, states: rules, alwaysGuided: settings.alwaysGuided)
        } ?? .guided
    session.player.advance(hintLevel: hint)
    if !session.player.isComplete { session.stepStartedAt = .now }
    self.session = session
    if session.player.isComplete { commitChain() } else { persistCheckpoint() }
  }
  private func commitChain() {
    guard var session, session.player.isComplete, !session.committed.contains(session.position)
    else { return }
    let now = Date.now
    let results = session.player.results
    let completion = SyncedCompletion(
      chainID: session.current.id, completedAt: now, mode: session.mode.rawValue,
      firstTryRate: Double(results.filter(\.firstTryCorrect).count) / Double(max(1, results.count)),
      durationSeconds: max(1, Int(now.timeIntervalSince(session.startedAt))))
    let previousRules = rules
    do {
      if session.mode == .forward || session.mode == .peel {
        // First-encounter protection applies to every appearance within this chain.
        let newRules = Set(rules.filter { $0.value.lastSeen == nil }.map(\.key))
        for result in results {
          for id in result.ruleIDs {
            var state = rules[id] ?? RuleState(ruleId: id, now: now)
            state.update(
              correct: !result.failedRuleIDs.contains(id), now: now, hintLevel: result.hintLevel,
              chainID: session.current.id, firstEncounter: newRules.contains(id))
            rules[id] = state
          }
          context.insert(
            StepAttemptRecord(
              chainID: session.current.id, result: result, at: now, completionKey: completion.key))
        }
        UnlockGraph.refresh(rules: pack.rules, states: &rules, now: now)
        try writeRules()
        let original =
          session.mode == .peel
          ? pack.chains.first { $0.id == session.current.id } : session.current
        let cloud = try cloudRecord()
        var counters = try cloud.snapshot()
        try counters.record(completion, replicaID: cloud.replicaID)
        context.insert(ChainRecord(completion, snapshot: original))
        try recordVocabulary(original ?? session.current, at: now)
        let today = PracticeDay.key(now)
        let dayRecords = try context.fetch(FetchDescriptor<StreakDay>())
        let completedToday: Int
        if let record = dayRecords.first(where: { $0.day == today }) {
          record.chainsCompleted += 1
          completedToday = record.chainsCompleted
        } else {
          context.insert(StreakDay(day: today, chainsCompleted: 1))
          completedToday = 1
        }
        counters.streak = try counters.streak.merging(days: [today: completedToday])
        try cloud.apply(counters)
        let oldest = now.addingTimeInterval(-90 * 86_400)
        for attempt in try context.fetch(FetchDescriptor<StepAttemptRecord>())
        where attempt.at < oldest { context.delete(attempt) }
      } else if session.mode == .placement {
        session.placementResults += results
        session.placementBands += Array(repeating: session.current.cefr, count: results.count)
      }
      session.committed.insert(session.position)
      session.phase = .chainSummary
      self.session = session
      try writeCheckpoint()
      try context.save()
      try reload()
      backend.event(
        "chain_complete",
        [
          "chain_id": session.current.id, "first_try_rate": completion.firstTryRate,
          "duration_s": completion.durationSeconds,
          "words_gained": Sentence.wordCount(session.current.final.tokens)
            - Sentence.wordCount(session.current.base.tokens),
        ])
      for id in session.current.ruleIDs {
        if let updated = rules[id],
          updated.hintLevel.rawValue > (previousRules[id]?.hintLevel.rawValue ?? 1)
        {
          backend.event("rule_level_up", ["rule_id": id, "new_level": updated.hintLevel.rawValue])
        }
      }
    } catch {
      context.rollback()
      rules = previousRules
      self.session = session
      self.session?.committed.remove(session.position)
      self.session?.phase = .playing
      errorMessage =
        "Progress couldn’t be saved. Please try Continue again before leaving this lesson."
    }
  }
  func nextChain() {
    guard var session, session.phase == .chainSummary else { return }
    if session.position + 1 >= session.queue.count {
      if session.mode == .demo {
        backend.event(
          "demo_completed", ["duration_s": Int(Date.now.timeIntervalSince(session.startedAt))])
        onboardingPage = 2
        finishSession()
        return
      }
      if session.mode == .placement {
        completePlacement(session)
        return
      }
      session.phase = .sessionSummary
      self.session = session
      settings.completedSessions += 1
      persistCheckpoint()
      Task { await syncProgress(force: true) }
      return
    }
    session.position += 1
    session.startedAt = .now
    session.stepStartedAt = .now
    session.phase = .playing
    let chain = session.current
    let hint =
      session.mode == .placement
      ? HintLevel.free
      : UnlockGraph.hintLevel(
        for: chain.steps[0], states: rules, alwaysGuided: settings.alwaysGuided)
    session.player = ChainPlayer(chain: chain, hintLevel: hint)
    self.session = session
    persistCheckpoint()
    backend.event(
      "chain_start",
      ["chain_id": chain.id, "mode": session.mode.rawValue, "pack_version": pack.version])
  }
  private func completePlacement(_ session: PracticeSession) {
    let combined = Array(zip(session.placementBands, session.placementResults))
    let result = PlacementResult.evaluate(results: combined, now: .now)
    rules.merge(result.states, uniquingKeysWith: { _, new in new })
    settings.band = result.band
    UnlockGraph.refresh(rules: pack.rules, states: &rules, now: .now)
    do {
      try writeRules()
      try context.save()
      onboardingPage = 3
      finishSession()
      refreshToday()
    } catch {
      context.rollback()
      errorMessage = "Your level couldn’t be saved. Please try again."
    }
    backend.event(
      "placement_completed", ["band": result.band.rawValue, "accuracy": result.accuracy])
  }
  func pause() {
    audio.stop()
    persistCheckpoint()
    showPractice = false
  }
  func finishSession() {
    if let session, [.forward, .peel].contains(session.mode), !session.committed.isEmpty,
      session.phase != .sessionSummary
    {
      settings.completedSessions += 1
    }
    audio.stop()
    session = nil
    showPractice = false
    do {
      for row in try context.fetch(FetchDescriptor<SessionCheckpoint>()) { context.delete(row) }
      try context.save()
    } catch {
      context.rollback()
      errorMessage = "The session couldn’t be closed. Your completed chains are saved."
    }
    refreshToday()
  }
  func openPaywall(_ trigger: String) {
    guard settings.completedSessions > 0 || trigger == "settings" else { return }
    paywallTrigger = trigger
    showPaywall = true
    backend.event("paywall_view", ["trigger": trigger])
  }
  private func writeRules() throws {
    let records = try context.fetch(FetchDescriptor<RuleStateRecord>())
    let byID = Dictionary(records.map { ($0.ruleId, $0) }, uniquingKeysWith: { _, last in last })
    for state in rules.values {
      if let record = byID[state.ruleId] {
        record.apply(state)
      } else {
        context.insert(RuleStateRecord(state))
      }
    }
  }
  private func writeCheckpoint() throws {
    let checkpoints = try context.fetch(FetchDescriptor<SessionCheckpoint>())
    guard let session else {
      for row in checkpoints { context.delete(row) }
      return
    }
    let data = try JSONEncoder().encode(session)
    if let row = checkpoints.first {
      row.data = data
      row.updatedAt = .now
    } else {
      context.insert(SessionCheckpoint(data: data))
    }
  }
  private func persistCheckpoint() {
    do {
      try writeCheckpoint()
      try context.save()
    } catch {
      context.rollback()
      errorMessage = "This step couldn’t be saved. Please keep Ripple open and try again."
    }
  }
  func progressSnapshot() -> ProgressSnapshot {
    ProgressSnapshot(rules: rules, chains: completions.map(\.value), streak: days)
  }
  private func cloudRecord() throws -> CloudProgressRecord {
    if let record = try context.fetch(FetchDescriptor<CloudProgressRecord>()).first { return record }
    let migrated = try CompactProgress.migrating(.init(chains: completions.map(\.value), streak: days))
    let record = try CloudProgressRecord(migrated)
    context.insert(record)
    return record
  }
  func cloudSnapshot() throws -> CompactProgress {
    var value = try cloudRecord().snapshot()
    value.rules = rules
    return try value.validated()
  }
  func importCloudProgress(_ remote: CompactProgress) throws {
    do {
      let before = try cloudSnapshot()
      let merged = try CompactProgress.merge(before, remote)
      rules = merged.rules
      try writeRules()
      let keys = Set(completions.map(\.key))
      let catalog = Dictionary(pack.chains.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
      for value in merged.latestCompletions where !keys.contains(value.key) {
        context.insert(ChainRecord(value, snapshot: catalog[value.chainID]))
      }
      for (key, aggregate) in merged.chains {
        let added = aggregate.completedCount - (before.chains[key]?.completedCount ?? 0)
        if added > 0, let chain = catalog[aggregate.latest.chainID] {
          try recordVocabulary(chain, at: aggregate.latest.completedAt, increment: added)
        }
      }
      let existing = try context.fetch(FetchDescriptor<StreakDay>())
      let byDay = Dictionary(existing.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
      for (key, count) in merged.streak.expandedDays {
        if let day = byDay[key] {
          day.chainsCompleted = max(day.chainsCompleted, count)
        } else {
          context.insert(StreakDay(day: key, chainsCompleted: count))
        }
      }
      try cloudRecord().apply(merged)
      try context.save()
      try reload()
      refreshToday()
    } catch {
      context.rollback()
      try? reload()
      throw error
    }
  }
  func exportData() throws -> Data {
    try purgeAttemptHistory()
    try context.save()
    try reload()
    struct Attempt: Encodable {
      let chainId: String
      let stepIndex: Int
      let hintLevel: Int
      let firstTryCorrect: Bool
      let attempts: Int
      let ruleIds: [String]
      let failedRuleIds: [String]
      let at: Date
      init(_ record: StepAttemptRecord) {
        chainId = record.chainId
        stepIndex = record.stepIndex
        hintLevel = record.hintLevel
        firstTryCorrect = record.firstTryCorrect
        attempts = record.attempts
        ruleIds = record.ruleIds
        failedRuleIds = record.failedRuleIds
        at = record.at
      }
    }
    struct Report: Encodable {
      let id: String
      let chainId: String
      let step: Int
      let packVersion: Int
      let reason: String
      let note: String
      let createdAt: Date
      let sent: Bool
      init(_ record: ContentReportRecord) {
        id = record.id
        chainId = record.chainId
        step = record.step
        packVersion = record.packVersion
        reason = record.reason
        note = record.note
        createdAt = record.createdAt
        sent = record.sent
      }
    }
    struct Export: Encodable {
      let schemaVersion: Int
      let exportedAt: Date
      let packId: String
      let packVersion: Int
      let progress: ProgressSnapshot
      let cloudProgress: CompactProgress
      let attemptHistory: [Attempt]
      let contentReports: [Report]
      let vocabulary: [String: Int]
      let practiceLevel: String
      let dailyGoal: Int
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(
      Export(
        schemaVersion: 2, exportedAt: .now, packId: pack.packId, packVersion: pack.version,
        progress: progressSnapshot(), cloudProgress: try cloudSnapshot(),
        attemptHistory: history.map(Attempt.init), contentReports: reports.map(Report.init),
        vocabulary: vocabulary,
        practiceLevel: settings.band.rawValue,
        dailyGoal: settings.dailyGoal))
  }
  private func recordVocabulary(_ chain: Chain, at: Date, increment: Int = 1) throws {
    let records = try context.fetch(FetchDescriptor<VocabularyExposureRecord>())
    let byLemma = Dictionary(records.map { ($0.lemma, $0) }, uniquingKeysWith: { _, last in last })
    let lemmas =
      chain.lemmas
      ?? Set(
        ([chain.base] + chain.steps.map(\.snapshot)).flatMap(\.tokens).filter { $0.pos != "PUNCT" }
          .compactMap(\.lemma)
      ).sorted()
    for lemma in Set(lemmas) {
      if let record = byLemma[lemma] {
        record.count += increment
        record.lastSeen = max(record.lastSeen, at)
      } else {
        let record = VocabularyExposureRecord(lemma: lemma, at: at)
        record.count = increment
        context.insert(record)
      }
    }
  }
  func syncProgress(force: Bool = false) async {
    guard !syncing, backend.isConfigured, backend.syncEnabled, let userID = backend.userID else {
      return
    }
    let key = "lastSync.\(userID)"
    if !force, let last = UserDefaults.standard.object(forKey: key) as? Date,
      Date.now.timeIntervalSince(last) < 600
    {
      return
    }
    syncing = true
    defer { syncing = false }
    do {
      let remote = try await FirestoreProgressSync().sync(cloudSnapshot(), userID: userID)
      // Account switches and sign-out while the network was in flight cannot import data.
      guard backend.userID == userID else { return }
      try importCloudProgress(remote)
      UserDefaults.standard.set(Date.now, forKey: key)
      syncMessage = "Up to date"
    } catch {
      context.rollback()
      try? reload()
      syncMessage = "Couldn’t sync yet. Your progress is saved on this device."
    }
  }
  private func checkForContentUpdate() async {
    guard let updater, backend.contentVersion > pack.version else { return }
    do {
      let record = try context.fetch(FetchDescriptor<PackState>()).first ?? PackState()
      if let last = record.lastManifestCheck, Date.now.timeIntervalSince(last) < 12 * 3600 {
        return
      }
      let announcedKey = "contentAnnounced.\(backend.contentVersion)"
      let announced = UserDefaults.standard.object(forKey: announcedKey) as? Date ?? .now
      UserDefaults.standard.set(announced, forKey: announcedKey)
      guard
        ContentUpdater.rolloutAllowed(
          installID: settings.installID, announcedAt: announced, now: .now)
      else { return }
      record.lastManifestCheck = .now
      context.insert(record)
      try context.save()
      if let newPack = try await updater.update(currentVersion: pack.version, appVersion: "1.0.0") {
        pack = newPack
        record.installedVersion = newPack.version
        try context.save()
        UnlockGraph.refresh(rules: pack.rules, states: &rules, now: .now)
        refreshToday()
      }
    } catch { /* Installed or bundled content remains available; retry in the next window. */  }
  }
  func submitReport(chainID: String, step: Int, reason: String, note: String) async -> Bool {
    let allowed = ["other_answer_ok", "answer_wrong", "bad_translation", "audio", "other"]
    guard allowed.contains(reason),
      pack.chains.contains(where: { $0.id == chainID }) || chainID == DemoContent.chain.id
    else { return false }
    let report = ContentReportRecord(
      chainId: chainID, step: step, packVersion: pack.version, reason: reason, note: note)
    context.insert(report)
    do {
      try context.save()
      try reload()
    } catch {
      context.rollback()
      errorMessage = "Your report couldn’t be saved."
      return false
    }
    if backend.isConfigured {
      do {
        try await backend.sendReport(report)
        report.sent = true
        try context.save()
      } catch {
        syncMessage =
          "Your report is saved on this device. You can send it again from Report History."
      }
    }
    return true
  }
  func resendReport(_ report: ContentReportRecord) async {
    do {
      try await backend.sendReport(report)
      report.sent = true
      try context.save()
    } catch { errorMessage = "The report couldn’t be sent. It is still saved on this device." }
  }
  func resetProgress() {
    do {
      try backend.signOut()
      try context.delete(model: RuleStateRecord.self)
      try context.delete(model: ChainRecord.self)
      try context.delete(model: StepAttemptRecord.self)
      try context.delete(model: StreakDay.self)
      try context.delete(model: SessionCheckpoint.self)
      try context.delete(model: VocabularyExposureRecord.self)
      try context.delete(model: CloudProgressRecord.self)
      try context.save()
      session = nil
      settings.completedSessions = 0
      settings.band = .a1
      UserDefaults.standard.removeObject(forKey: "focusedPracticeDay")
      try reload()
      refreshToday()
    } catch {
      context.rollback()
      errorMessage = "Progress couldn’t be reset. Please try again."
    }
  }
}

enum DemoContent {
  static var chain: Chain {
    let base = [
      Token(id: "s", text: "ich", lemma: "ich", pos: "PRON"),
      Token(id: "v", text: "trinke", lemma: "trinken", pos: "VERB"),
      Token(id: "n", text: "Kaffee", lemma: "Kaffee", pos: "NOUN"),
    ]
    var one = base
    one[0].text = "wir"
    one[0].lemma = "wir"
    one[1].text = "trinken"
    var two = one
    two.insert(Token(id: "d", text: "einen", lemma: "ein", pos: "DET", initial: "ein"), at: 2)
    var three = two
    three[2].initial = nil
    three.insert(Token(id: "a", text: "großen", lemma: "groß", pos: "ADJ", initial: "groß"), at: 3)
    return Chain(
      chainId: "demo", title: ["en": "Your first ripple"],
      base: Snapshot(tokens: base, gloss: ["en": "I drink coffee."]),
      steps: [
        Step(
          card: Card(
            type: .substitute, target: "s", label: "ich → wir", cardGloss: ["en": "I → we"]),
          inverseLabel: "wir → ich", tokens: one,
          fixes: [
            Dependency(
              token: "v", rules: ["verb.present.regular"],
              distractors: ["trinke", "trinkt", "trinkst"])
          ], gloss: ["en": "We drink coffee."]),
        Step(
          card: Card(type: .insert, label: "+ ein", cardGloss: ["en": "+ a"], slots: ["before:n"]),
          inverseLabel: "− einen", tokens: two,
          fixes: [
            Dependency(
              token: "d", rules: ["article.indef.acc"], distractors: ["ein", "einem", "eine"])
          ], gloss: ["en": "We have a coffee."]),
        Step(
          card: Card(
            type: .insert, label: "+ groß", cardGloss: ["en": "+ large"], slots: ["before:n"]),
          inverseLabel: "− großen", tokens: three,
          fixes: [
            Dependency(
              token: "a", rules: ["adj.decl.mixed"], distractors: ["großer", "großem", "große"])
          ], gloss: ["en": "We have a large coffee."]),
      ])
  }
}
