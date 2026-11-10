import Foundation
import LearningModel

public struct SyncedCompletion: Codable, Equatable, Sendable {
  public var chainID: String
  public var completedAt: Date
  public var mode: String
  public var firstTryRate: Double
  public var durationSeconds: Int
  public var key: String { "\(chainID)|\(completedAt.timeIntervalSince1970)|\(mode)" }
  public init(
    chainID: String, completedAt: Date, mode: String, firstTryRate: Double, durationSeconds: Int
  ) {
    self.chainID = chainID
    self.completedAt = completedAt
    self.mode = mode
    self.firstTryRate = firstTryRate
    self.durationSeconds = durationSeconds
  }
}

public struct ProgressSnapshot: Codable, Equatable, Sendable {
  public var schemaVersion: Int = 1
  public var rules: [String: RuleState]
  public var chains: [SyncedCompletion]
  public var streak: [String: Int]
  public init(
    rules: [String: RuleState] = [:], chains: [SyncedCompletion] = [], streak: [String: Int] = [:]
  ) {
    self.rules = rules
    self.chains = chains
    self.streak = streak
  }
  public func validated() throws -> Self {
    guard schemaVersion == 1, rules.count <= 200, chains.count <= 4000, streak.count <= 4000,
      rules.allSatisfy({ key, rule in
        key == rule.ruleId && key.count <= 100 && rule.strength.isFinite
          && (0...1).contains(rule.strength)
          && rule.intervalDays.isFinite && (0...60).contains(rule.intervalDays)
          && (0...1_000_000_000).contains(rule.attempts) && rule.firstTryCorrect >= 0
          && rule.firstTryCorrect <= rule.attempts
          && rule.dueDate.timeIntervalSince1970.isFinite
          && (rule.lastSeen?.timeIntervalSince1970.isFinite ?? true)
          && rule.freeCorrectChainIDs.count <= 240
          && rule.freeCorrectChainIDs.allSatisfy({ $0.count <= 64 })
      }),
      chains.allSatisfy({
        $0.chainID.count <= 64 && ["forward", "peel"].contains($0.mode) && $0.firstTryRate.isFinite
          && (0...1).contains($0.firstTryRate) && $0.durationSeconds >= 0
      }),
      streak.values.allSatisfy({ (0...1000).contains($0) })
    else { throw SyncError.invalidData }
    return self
  }
  public static func merge(_ a: Self, _ b: Self) -> Self {
    var rules = a.rules
    for (id, incoming) in b.rules {
      guard let current = rules[id] else {
        rules[id] = incoming
        continue
      }
      let oldDate = current.lastSeen ?? .distantPast
      let newDate = incoming.lastSeen ?? .distantPast
      if newDate > oldDate || (newDate == oldDate && tieBreak(incoming) > tieBreak(current)) {
        rules[id] = incoming
      }
    }
    var completions = Dictionary(a.chains.map { ($0.key, $0) }, uniquingKeysWith: chooseCompletion)
    for completion in b.chains {
      completions[completion.key] =
        completions[completion.key].map { chooseCompletion($0, completion) } ?? completion
    }
    return Self(
      rules: rules, chains: completions.values.sorted { $0.key < $1.key },
      streak: a.streak.merging(b.streak, uniquingKeysWith: max))
  }
  private static func tieBreak(_ state: RuleState) -> String {
    // Sets encode in unspecified order: explicitly canonicalize the entire tie breaker.
    "\(state.attempts)|\(state.strength)|\(state.intervalDays)|\(state.dueDate.timeIntervalSince1970)|\(state.firstTryCorrect)|\(state.unlocked)|\(state.freeCorrectChainIDs.sorted().joined(separator: ","))"
  }
  private static func chooseCompletion(_ a: SyncedCompletion, _ b: SyncedCompletion)
    -> SyncedCompletion
  {
    if a.firstTryRate != b.firstTryRate { return a.firstTryRate > b.firstTryRate ? a : b }
    return a.durationSeconds >= b.durationSeconds ? a : b
  }
}

public enum SyncError: Error, LocalizedError {
  case unavailable, invalidData, documentTooLarge, reauthenticationRequired
  public var errorDescription: String? {
    switch self {
    case .unavailable: "Sync isn’t available in this build. Your progress is saved on this device."
    case .invalidData: "Synced progress could not be read. Your progress on this device is safe."
    case .documentTooLarge: "Progress is too large to sync. Your progress is saved on this device."
    case .reauthenticationRequired: "Sign in with Apple again to finish deleting your account."
    }
  }
}

public protocol ProgressSyncing: Sendable {
  func sync(_ local: CompactProgress, userID: String) async throws -> CompactProgress
  func deleteProgress(userID: String) async throws
}
public struct NoopProgressSync: ProgressSyncing {
  public init() {}
  public func sync(_ local: CompactProgress, userID: String) async throws -> CompactProgress {
    local
  }
  public func deleteProgress(userID: String) async throws {}
}
