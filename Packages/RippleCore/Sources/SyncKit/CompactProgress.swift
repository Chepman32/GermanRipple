import Foundation
import LearningModel

/// Cloud state grows with the catalog and installations, rather than every practice session.
/// Detailed completion events remain in the local store and its export.
public struct CompactProgress: Codable, Equatable, Sendable {
  public var schemaVersion = 2
  public var rules: [String: RuleState]
  public var chains: [String: ChainAggregate]
  public var streak: CompactStreak

  public init(
    rules: [String: RuleState] = [:], chains: [String: ChainAggregate] = [:],
    streak: CompactStreak = .init()
  ) {
    self.rules = rules
    self.chains = chains
    self.streak = streak
  }

  public var completedCount: Int { chains.values.reduce(0) { $0 + $1.completedCount } }
  public var latestCompletions: [SyncedCompletion] {
    chains.values.map(\.latest).sorted { $0.key < $1.key }
  }

  public func validated() throws -> Self {
    guard schemaVersion == 2, chains.count <= 1024,
      chains.values.reduce(0, { $0 + $1.legacyCount }) <= 100_000
    else { throw SyncError.invalidData }
    _ = try ProgressSnapshot(rules: rules).validated()
    for (key, value) in chains {
      guard key == value.latest.aggregateKey else { throw SyncError.invalidData }
      try value.validate()
    }
    try streak.validate()
    return self
  }

  /// The caller commits this counter and its completion/checkpoint in one local transaction.
  public mutating func record(_ completion: SyncedCompletion, replicaID: String) throws {
    guard UUID(uuidString: replicaID) != nil else { throw SyncError.invalidData }
    try completion.validate()
    var aggregate = chains[completion.aggregateKey] ?? ChainAggregate(latest: completion)
    aggregate.include(completion)
    let current = aggregate.counts[replicaID, default: 0]
    guard current < 1_000_000_000 else { throw SyncError.invalidData }
    aggregate.counts[replicaID] = current + 1
    chains[completion.aggregateKey] = aggregate
  }

  /// Preserve the exact legacy event union as packed IEEE-754 timestamp bits,
  /// grouped by chain and mode. This uses eight bytes per event before base64.
  /// New events use counters, so the migration payload never grows afterwards.
  public static func migrating(_ legacy: ProgressSnapshot) throws -> Self {
    _ = try ProgressSnapshot(rules: legacy.rules).validated()
    guard legacy.schemaVersion == 1, legacy.chains.count <= 100_000 else {
      throw SyncError.invalidData
    }
    var result = Self(rules: legacy.rules, streak: try CompactStreak(days: legacy.streak))
    var instants: [String: Set<UInt64>] = [:]
    for completion in legacy.chains {
      try completion.validate()
      var aggregate = result.chains[completion.aggregateKey] ?? ChainAggregate(latest: completion)
      aggregate.include(completion)
      instants[completion.aggregateKey, default: []].insert(
        (completion.completedAt.timeIntervalSince1970 + 0.0).bitPattern)
      result.chains[completion.aggregateKey] = aggregate
    }
    for (key, bits) in instants {
      result.chains[key]?.legacyInstants = ChainAggregate.encodeInstants(bits.sorted())
    }
    return try result.validated()
  }

  public static func merge(_ a: Self, _ b: Self) throws -> Self {
    _ = try a.validated()
    _ = try b.validated()
    var chains = a.chains
    for (key, incoming) in b.chains {
      chains[key] = chains[key].map { ChainAggregate.merge($0, incoming) } ?? incoming
    }
    return try Self(
      rules: ProgressSnapshot.merge(.init(rules: a.rules), .init(rules: b.rules)).rules,
      chains: chains, streak: CompactStreak.merge(a.streak, b.streak)
    ).validated()
  }
}

public struct ChainAggregate: Codable, Equatable, Sendable {
  public var latest: SyncedCompletion
  public var firstCompletedAt: Date
  public var bestFirstTryRate: Double
  public var counts: [String: Int] = [:]
  public var legacyInstants: String = ""

  public init(latest: SyncedCompletion) {
    self.latest = latest
    firstCompletedAt = latest.completedAt
    bestFirstTryRate = latest.firstTryRate
  }
  fileprivate var legacyCount: Int { (Data(base64Encoded: legacyInstants)?.count ?? 0) / 8 }
  public var completedCount: Int { counts.values.reduce(legacyCount, +) }

  fileprivate mutating func include(_ completion: SyncedCompletion) {
    latest = Self.latestOf(latest, completion)
    firstCompletedAt = min(firstCompletedAt, completion.completedAt)
    bestFirstTryRate = max(bestFirstTryRate, completion.firstTryRate)
  }
  fileprivate static func merge(_ a: Self, _ b: Self) -> Self {
    var result = a
    result.include(b.latest)
    result.firstCompletedAt = min(a.firstCompletedAt, b.firstCompletedAt)
    result.bestFirstTryRate = max(a.bestFirstTryRate, b.bestFirstTryRate)
    result.counts = a.counts.merging(b.counts, uniquingKeysWith: max)
    result.legacyInstants = encodeInstants(
      Set(a.instantBits ?? []).union(b.instantBits ?? []).sorted())
    return result
  }
  private static func latestOf(_ a: SyncedCompletion, _ b: SyncedCompletion) -> SyncedCompletion {
    if a.completedAt != b.completedAt { return a.completedAt > b.completedAt ? a : b }
    if a.firstTryRate != b.firstTryRate { return a.firstTryRate > b.firstTryRate ? a : b }
    return a.durationSeconds >= b.durationSeconds ? a : b
  }
  fileprivate func validate() throws {
    try latest.validate()
    guard counts.count <= 128,
      counts.allSatisfy({ UUID(uuidString: $0.key) != nil && (1...1_000_000_000).contains($0.value) }),
      let instants = instantBits, instants.count <= 100_000,
      zip(instants, instants.dropFirst()).allSatisfy({ $0 < $1 }),
      instants.allSatisfy({
        let seconds = Double(bitPattern: $0)
        return seconds.isFinite && (0...253_402_300_799).contains(seconds)
      }),
      completedCount > 0, firstCompletedAt.timeIntervalSince1970.isFinite,
      firstCompletedAt >= .init(timeIntervalSince1970: 0), firstCompletedAt <= latest.completedAt,
      bestFirstTryRate.isFinite && (latest.firstTryRate...1).contains(bestFirstTryRate)
    else { throw SyncError.invalidData }
  }
  private var instantBits: [UInt64]? {
    guard let data = Data(base64Encoded: legacyInstants), data.count % 8 == 0,
      data.count <= 800_000, data.base64EncodedString() == legacyInstants
    else { return nil }
    return data.withUnsafeBytes { bytes in
      stride(from: 0, to: data.count, by: 8).map {
        UInt64(bigEndian: bytes.loadUnaligned(fromByteOffset: $0, as: UInt64.self))
      }
    }
  }
  fileprivate static func encodeInstants(_ values: [UInt64]) -> String {
    var data = Data(capacity: values.count * 8)
    for value in values {
      withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }
    return data.base64EncodedString()
  }
}

extension SyncedCompletion {
  public var aggregateKey: String { "\(chainID)|\(mode)" }
  fileprivate func validate() throws {
    guard !chainID.isEmpty, chainID.utf8.count <= 64,
      chainID.utf8.allSatisfy({
        (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
          || [45, 46, 95].contains($0)
      }), ["forward", "peel"].contains(mode),
      completedAt.timeIntervalSince1970.isFinite,
      (0...253_402_300_799).contains(completedAt.timeIntervalSince1970),
      firstTryRate.isFinite, (0...1).contains(firstTryRate),
      durationSeconds >= 0
    else { throw SyncError.invalidData }
  }
}

/// Exact counts for the most recent 400 calendar days; practiced-day presence
/// before that is an OR-merged, 46-byte bitmap per year. No rolling expiry can
/// erase a long streak or resurrect old days during an offline replay.
public struct CompactStreak: Codable, Equatable, Sendable {
  public var recent: [String: Int] = [:]
  public var archived: [String: String] = [:]
  public init() {}

  public init(days: [String: Int]) throws {
    guard days.allSatisfy({ Self.date($0.key) != nil && (0...1_000_000_000).contains($0.value) }) else {
      throw SyncError.invalidData
    }
    guard let latest = days.filter({ $0.value > 0 }).keys.max(), let date = Self.date(latest),
      let cutoff = Self.calendar.date(byAdding: .day, value: -399, to: date)
    else { return }
    let cutoffKey = Self.key(cutoff)
    for (key, count) in days where count > 0 {
      if key >= cutoffKey {
        recent[key] = count
      } else {
        let year = String(key.prefix(4))
        let day = Self.calendar.ordinality(of: .day, in: .year, for: Self.date(key)!)! - 1
        var bytes = archived[year].flatMap { Data(base64Encoded: $0) }.map { Array($0) }
          ?? Array(repeating: UInt8(0), count: 46)
        bytes[day / 8] |= UInt8(1 << (day % 8))
        archived[year] = Data(bytes).base64EncodedString()
      }
    }
  }

  public var expandedDays: [String: Int] {
    var result = recent
    for (year, encoded) in archived {
      guard let first = Self.date("\(year)-01-01"), let data = Data(base64Encoded: encoded),
        data.count == 46
      else { continue }
      for day in 0..<366 where (data[day / 8] & UInt8(1 << (day % 8))) != 0 {
        if let date = Self.calendar.date(byAdding: .day, value: day, to: first) {
          result[Self.key(date)] = max(1, result[Self.key(date), default: 0])
        }
      }
    }
    return result
  }

  public func merging(days: [String: Int]) throws -> Self {
    try validate()
    return try Self.merge(self, Self(days: days))
  }

  fileprivate static func merge(_ a: Self, _ b: Self) throws -> Self {
    var result = try Self(days: a.recent.merging(b.recent, uniquingKeysWith: max))
    for archive in [a.archived, b.archived] {
      for (year, encoded) in archive {
        let incoming = Array(Data(base64Encoded: encoded)!)
        var current = result.archived[year].flatMap { Data(base64Encoded: $0) }.map { Array($0) }
          ?? Array(repeating: UInt8(0), count: 46)
        for index in current.indices { current[index] |= incoming[index] }
        result.archived[year] = Data(current).base64EncodedString()
      }
    }
    return result
  }
  fileprivate func validate() throws {
    guard recent.count <= 400, archived.count <= 256,
      recent.allSatisfy({ Self.date($0.key) != nil && (1...1_000_000_000).contains($0.value) })
    else { throw SyncError.invalidData }
    guard let latest = recent.keys.max(), let latestDate = Self.date(latest) else {
      guard archived.isEmpty else { throw SyncError.invalidData }
      return
    }
    let cutoff = Self.calendar.date(byAdding: .day, value: -399, to: latestDate)!
    let cutoffKey = Self.key(cutoff)
    let cutoffYear = String(cutoffKey.prefix(4))
    guard recent.keys.allSatisfy({ $0 >= cutoffKey }) else { throw SyncError.invalidData }
    for (year, encoded) in archived {
      guard year.utf8.count == 4, let first = Self.date("\(year)-01-01"),
        let data = Data(base64Encoded: encoded), data.count == 46,
        data.base64EncodedString() == encoded, data.contains(where: { $0 != 0 }), year <= cutoffYear
      else { throw SyncError.invalidData }
      let limit = year == cutoffYear
        ? Self.calendar.ordinality(of: .day, in: .year, for: cutoff)! - 1
        : Self.calendar.range(of: .day, in: .year, for: first)!.count
      for bit in limit..<368 where (data[bit / 8] & UInt8(1 << (bit % 8))) != 0 {
        throw SyncError.invalidData
      }
    }
  }

  private static var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }
  private static func date(_ key: String) -> Date? {
    let bytes = Array(key.utf8)
    guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
      bytes.enumerated().allSatisfy({ [4, 7].contains($0.offset) || (48...57).contains($0.element) }),
      let year = Int(key.prefix(4)), (1900...9999).contains(year),
      let month = Int(key.dropFirst(5).prefix(2)), let day = Int(key.suffix(2)),
      let result = calendar.date(from: DateComponents(year: year, month: month, day: day)),
      Self.key(result) == key
    else { return nil }
    return result
  }
  private static func key(_ date: Date) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }
}
