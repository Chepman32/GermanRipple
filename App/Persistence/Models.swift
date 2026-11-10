import Foundation
import LearningModel
import RippleEngine
import SwiftData
import SyncKit

@Model final class RuleStateRecord {
  @Attribute(.unique) var key: String
  var packId: String
  var ruleId: String
  var strength: Double
  var intervalDays: Double
  var dueDate: Date
  var attempts: Int
  var firstTryCorrect: Int
  var lastSeen: Date?
  var unlocked: Bool
  var freeCorrectChainIDs: [String]
  init(_ state: RuleState, packId: String = "de-en") {
    self.key = "\(packId)|\(state.ruleId)"
    self.packId = packId
    ruleId = state.ruleId
    strength = state.strength
    intervalDays = state.intervalDays
    dueDate = state.dueDate
    attempts = state.attempts
    firstTryCorrect = state.firstTryCorrect
    lastSeen = state.lastSeen
    unlocked = state.unlocked
    freeCorrectChainIDs = state.freeCorrectChainIDs.sorted()
  }
  var value: RuleState {
    var state = RuleState(ruleId: ruleId, now: dueDate)
    state.strength = strength
    state.intervalDays = intervalDays
    state.dueDate = dueDate
    state.attempts = attempts
    state.firstTryCorrect = firstTryCorrect
    state.lastSeen = lastSeen
    state.unlocked = unlocked
    state.freeCorrectChainIDs = Set(freeCorrectChainIDs)
    return state
  }
  func apply(_ state: RuleState) {
    strength = state.strength
    intervalDays = state.intervalDays
    dueDate = state.dueDate
    attempts = state.attempts
    firstTryCorrect = state.firstTryCorrect
    lastSeen = state.lastSeen
    unlocked = state.unlocked
    freeCorrectChainIDs = state.freeCorrectChainIDs.sorted()
  }
}

@Model final class ChainRecord {
  @Attribute(.unique) var key: String
  var packId: String = "de-en"
  var chainId: String
  var mode: String
  var completedAt: Date
  var firstTryRate: Double
  var durationSeconds: Int
  var snapshotData: Data?
  init(_ value: SyncedCompletion, snapshot: Chain? = nil) {
    key = value.key
    chainId = value.chainID
    mode = value.mode
    completedAt = value.completedAt
    firstTryRate = value.firstTryRate
    durationSeconds = value.durationSeconds
    snapshotData = snapshot.flatMap { try? JSONEncoder().encode($0) }
  }
  var value: SyncedCompletion {
    .init(
      chainID: chainId, completedAt: completedAt, mode: mode, firstTryRate: firstTryRate,
      durationSeconds: durationSeconds)
  }
  var chain: Chain? { snapshotData.flatMap { try? JSONDecoder().decode(Chain.self, from: $0) } }
}

@Model final class StepAttemptRecord {
  @Attribute(.unique) var key: String
  var chainId: String
  var stepIndex: Int
  var hintLevel: Int
  var firstTryCorrect: Bool
  var attempts: Int
  var ruleIds: [String]
  var failedRuleIds: [String]
  var at: Date
  init(chainID: String, result: StepResult, at: Date, completionKey: String) {
    key = "\(completionKey)|\(result.index)"
    chainId = chainID
    stepIndex = result.index
    hintLevel = result.hintLevel.rawValue
    firstTryCorrect = result.firstTryCorrect
    attempts = result.attempts
    ruleIds = result.ruleIDs
    failedRuleIds = result.failedRuleIDs.sorted()
    self.at = at
  }
}

@Model final class StreakDay {
  @Attribute(.unique) var day: String
  var chainsCompleted: Int
  var usedFreeze: Bool
  init(day: String, chainsCompleted: Int, usedFreeze: Bool = false) {
    self.day = day
    self.chainsCompleted = chainsCompleted
    self.usedFreeze = usedFreeze
  }
}

@Model final class PackState {
  @Attribute(.unique) var packId: String
  var installedVersion: Int
  var lastManifestCheck: Date?
  init(packId: String = "de-en", installedVersion: Int = 1) {
    self.packId = packId
    self.installedVersion = installedVersion
  }
}

@Model final class ContentReportRecord {
  @Attribute(.unique) var id: String
  var chainId: String
  var step: Int
  var packVersion: Int
  var reason: String
  var note: String
  var createdAt: Date
  var sent: Bool
  init(chainId: String, step: Int, packVersion: Int, reason: String, note: String) {
    id = UUID().uuidString
    self.chainId = chainId
    self.step = step
    self.packVersion = packVersion
    self.reason = reason
    self.note = String(note.prefix(500))
    createdAt = .now
    sent = false
  }
}

@Model final class SessionCheckpoint {
  @Attribute(.unique) var id: String
  var data: Data
  var updatedAt: Date
  init(id: String = "active", data: Data) {
    self.id = id
    self.data = data
    updatedAt = .now
  }
}

@Model final class CloudProgressRecord {
  @Attribute(.unique) var packId: String
  var replicaID: String
  var data: Data
  init(_ value: CompactProgress, packId: String = "de-en") throws {
    self.packId = packId
    replicaID = UUID().uuidString
    data = try JSONEncoder().encode(value)
  }
  func snapshot() throws -> CompactProgress {
    try JSONDecoder().decode(CompactProgress.self, from: data).validated()
  }
  func apply(_ value: CompactProgress) throws {
    // Rule models are separate. Keep the compact history here so a normal sync
    // never has to rebuild decades of archived days from individual local rows.
    data = try JSONEncoder().encode(
      CompactProgress(chains: value.chains, streak: value.streak).validated())
  }
}

enum Persistence {
  static let schema = Schema([
    RuleStateRecord.self, ChainRecord.self, StepAttemptRecord.self, StreakDay.self, PackState.self,
    ContentReportRecord.self, SessionCheckpoint.self, VocabularyExposureRecord.self,
    CloudProgressRecord.self,
  ])
  static func container(inMemory: Bool = false) throws -> ModelContainer {
    if !inMemory {
      try FileManager.default.createDirectory(
        at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
    }
    return try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(
        schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none))
  }
}
