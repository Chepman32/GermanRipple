import Foundation
import LearningModel
import SyncKit
import Testing

@Suite struct CompactSyncTests {
  private let deviceA = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
  private let deviceB = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB"
  private let deviceC = "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC"
  private func completion(_ second: Int, chain: String = "de.a1.read.000", rate: Double = 1)
    -> SyncedCompletion
  {
    .init(chainID: chain, completedAt: .init(timeIntervalSince1970: Double(second)),
      mode: "forward", firstTryRate: rate, durationSeconds: 90)
  }

  @Test func offlineBranchesConvergeWithoutCountingSharedHistoryTwice() throws {
    var shared = CompactProgress()
    try shared.record(completion(100), replicaID: deviceA)
    try shared.record(completion(200), replicaID: deviceA)
    var a = shared
    var b = shared
    var c = CompactProgress()
    try a.record(completion(300, rate: 0.6), replicaID: deviceA)
    try b.record(completion(400, rate: 0.8), replicaID: deviceB)
    try c.record(completion(500), replicaID: deviceC)
    let merged = try CompactProgress.merge(a, b)
    #expect(merged.completedCount == 4)
    #expect(merged == (try CompactProgress.merge(b, a)))
    #expect(merged == (try CompactProgress.merge(merged, shared)))
    #expect(merged == (try CompactProgress.merge(merged, merged)))
    #expect(try CompactProgress.merge(merged, c)
      == CompactProgress.merge(a, CompactProgress.merge(b, c)))
    let aggregate = try #require(merged.chains.values.first)
    #expect(aggregate.latest.completedAt == completion(400).completedAt)
    #expect(aggregate.bestFirstTryRate == 1)
    #expect(aggregate.firstCompletedAt == completion(100).completedAt)
  }

  @Test func twentyThousandSessionsStaySmallAndPreserveTotals() throws {
    var state = CompactProgress()
    for second in 1...20_000 {
      try state.record(completion(second, chain: "de.a1.read.\(second % 3)"), replicaID: deviceA)
    }
    _ = try state.validated()
    #expect(state.completedCount == 20_000)
    #expect(state.chains.count == 3)
    #expect(state.latestCompletions.count == 3)
    #expect(try JSONEncoder().encode(state).count < 2_000)
    let restored = try JSONDecoder().decode(CompactProgress.self, from: JSONEncoder().encode(state))
    #expect(restored == state)
  }

  @Test func legacyMigrationDeduplicatesOverlapsAndOfflineReplays() throws {
    let a = try CompactProgress.migrating(.init(chains: [completion(1), completion(2)]))
    let b = try CompactProgress.migrating(.init(chains: [completion(2), completion(3)]))
    var merged = try CompactProgress.merge(a, b)
    #expect(merged.completedCount == 3)
    #expect(merged.chains.count == 1)
    try merged.record(completion(4), replicaID: deviceA)
    #expect(try CompactProgress.merge(merged, b).completedCount == 4)
    #expect(try CompactProgress.merge(merged, a).completedCount == 4)
    let legacy = ProgressSnapshot(rules: [:], chains: [completion(1)], streak: [:])
    let bytes = try JSONEncoder().encode(legacy)
    #expect(try CompactProgress.migrating(JSONDecoder().decode(ProgressSnapshot.self, from: bytes))
      .completedCount == 1)
  }

  @Test func thirtyYearsOfStreaksUseBitmapsAndKeepLeapDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = try #require(calendar.date(from: .init(year: 2000, month: 1, day: 1)))
    var days: [String: Int] = [:]
    for offset in 0..<10_958 {
      let date = try #require(calendar.date(byAdding: .day, value: offset, to: start))
      let p = calendar.dateComponents([.year, .month, .day], from: date)
      days[String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)] = 3
    }
    let streak = try CompactStreak(days: days)
    _ = try CompactProgress(streak: streak).validated()
    #expect(streak.recent.count == 400)
    #expect(streak.expandedDays.count == days.count)
    #expect(streak.expandedDays["2000-02-29"] == 1)
    #expect(try JSONEncoder().encode(streak).count < 10_000)
    let stale = CompactProgress(streak: try CompactStreak(days: ["2000-02-29": 3]))
    let current = CompactProgress(streak: streak)
    #expect(try CompactProgress.merge(current, stale).streak == streak)
    #expect(try CompactProgress.merge(stale, current).streak == streak)
  }

  @Test func largeOfflineLegacyStoreCanMigratePastTheOldCloudLimit() throws {
    let events = (1...20_000).map { completion($0) }
    var state = try CompactProgress.migrating(.init(chains: events))
    #expect(state.completedCount == 20_000)
    #expect(try JSONEncoder().encode(state).count < 220_000)
    try state.record(completion(20_001), replicaID: deviceA)
    #expect(state.completedCount == 20_001)
    let oldRemote = try CompactProgress.migrating(.init(chains: Array(events.prefix(4000))))
    #expect(try CompactProgress.merge(state, oldRemote).completedCount == 20_001)
  }

  @Test func malformedCloudStateIsRejectedBeforeImport() throws {
    var valid = CompactProgress()
    try valid.record(completion(100), replicaID: deviceA)
    let key = completion(100).aggregateKey
    var invalid = valid
    invalid.chains[key]?.counts[deviceA] = -1
    #expect(throws: SyncError.self) { try invalid.validated() }
    invalid = valid
    invalid.chains[key]?.latest.completedAt = .init(timeIntervalSince1970: -.infinity)
    #expect(throws: SyncError.self) { try invalid.validated() }
    #expect(throws: SyncError.self) { try CompactStreak(days: ["2027-02-29": 1]) }
    #expect(throws: SyncError.self) { try valid.record(completion(101), replicaID: "not-a-device") }
    var invalidStreak = CompactStreak()
    invalidStreak.archived["2027"] = Data(repeating: 255, count: 46).base64EncodedString()
    #expect(throws: SyncError.self) { try CompactProgress(streak: invalidStreak).validated() }
  }
}
