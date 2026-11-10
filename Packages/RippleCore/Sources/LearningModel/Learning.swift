import Foundation
import RippleEngine

public struct RuleState: Codable, Equatable, Sendable {
  public let ruleId: String
  public var strength: Double = 0
  public var intervalDays: Double = 0
  public var dueDate: Date
  public var attempts: Int = 0
  public var firstTryCorrect: Int = 0
  public var lastSeen: Date?
  public var unlocked: Bool = false
  public var freeCorrectChainIDs: Set<String> = []
  public var hintLevel: HintLevel { strength < 0.4 ? .guided : strength <= 0.75 ? .counted : .free }
  public var segments: Int { Int(floor(min(1, max(0, strength)) * 5)) }
  public var mastered: Bool { strength > 0.85 && freeCorrectChainIDs.count >= 3 }
  public init(ruleId: String, now: Date) {
    self.ruleId = ruleId
    dueDate = now
  }

  public mutating func update(
    correct: Bool, now: Date, hintLevel: HintLevel, chainID: String, firstEncounter: Bool = false
  ) {
    // An introduction is an exposure. It cannot penalize a learner for an unseen rule.
    if firstEncounter && !correct {
      lastSeen = now
      unlocked = true
      return
    }
    attempts += 1
    lastSeen = now
    unlocked = true
    if correct {
      firstTryCorrect += 1
      strength += 0.25 * (1 - strength)
      intervalDays = min(60, max(1, intervalDays * 2.2))
      if hintLevel == .free { freeCorrectChainIDs.insert(chainID) }
    } else {
      strength *= 0.6
      intervalDays = 1
    }
    dueDate = now.addingTimeInterval(intervalDays * 86_400)
  }
}

public enum UnlockGraph {
  public static func available(rule: Rule, states: [String: RuleState]) -> Bool {
    rule.prerequisites.allSatisfy { (states[$0]?.strength ?? 0) >= 0.4 }
  }
  public static func refresh(rules: [Rule], states: inout [String: RuleState], now: Date) {
    for rule in rules {
      var state = states[rule.id] ?? RuleState(ruleId: rule.id, now: now)
      state.unlocked = state.unlocked || available(rule: rule, states: states)
      states[rule.id] = state
    }
  }
  public static func hintLevel(
    for step: Step, states: [String: RuleState], alwaysGuided: Bool = false
  ) -> HintLevel {
    if alwaysGuided || step.ruleIDs.contains(where: { states[$0]?.lastSeen == nil }) {
      return .guided
    }
    let strength = step.ruleIDs.map { states[$0]?.strength ?? 0 }.min() ?? 0
    return strength < 0.4 ? .guided : strength <= 0.75 ? .counted : .free
  }
}

public struct ChainHistory: Codable, Equatable, Sendable {
  public var chainID: String
  public var completedAt: Date
  public init(chainID: String, completedAt: Date) {
    self.chainID = chainID
    self.completedAt = completedAt
  }
}

public struct SchedulerWeights: Codable, Sendable {
  public var overdue: Double = 3, weakness: Double = 2, introduction: Double = 1.5,
    overlap: Double = 2, themeVariety: Double = 0.5
  public init() {}
}

public struct Scheduler: Sendable {
  public var weights: SchedulerWeights
  public init(weights: SchedulerWeights = .init()) { self.weights = weights }

  public func select(
    chains: [Chain], rules: [Rule], states: [String: RuleState], history: [ChainHistory],
    band: CEFR, now: Date, count: Int = 3, focusing ruleID: String? = nil
  ) -> [Chain] {
    let definitions = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
    func newRules(_ chain: Chain) -> [String] {
      chain.ruleIDs.filter { states[$0]?.unlocked != true }.sorted()
    }
    func eligible(_ chain: Chain) -> Bool {
      guard chain.cefr <= band else { return false }
      let locked = newRules(chain)
      return locked.isEmpty
        || (locked.count == 1
          && definitions[locked[0]].map { UnlockGraph.available(rule: $0, states: states) } == true)
    }
    let all = chains.filter { eligible($0) && (ruleID == nil || $0.ruleIDs.contains(ruleID!)) }
    let lastPlayed = Dictionary(history.map { ($0.chainID, $0.completedAt) }, uniquingKeysWith: max)
    let fresh = all.filter {
      lastPlayed[$0.id].map { now.timeIntervalSince($0) >= 14 * 86_400 } ?? true
    }
    var pool = fresh
    if pool.count < count {
      pool += all.filter { candidate in !fresh.contains(where: { $0.id == candidate.id }) }.sorted {
        (lastPlayed[$0.id] ?? .distantPast) < (lastPlayed[$1.id] ?? .distantPast)
      }
    }
    var chosen: [Chain] = []
    while chosen.count < max(0, count) && !pool.isEmpty {
      let slot = chosen.count
      let seen = chosen.reduce(into: Set<String>()) { $0.formUnion($1.ruleIDs) }
      func score(_ chain: Chain) -> Double {
        let tags = chain.ruleIDs.sorted()
        let overdue = tags.reduce(0.0) { total, tag in
          guard let state = states[tag], state.lastSeen != nil else { return total }
          return total + min(7, max(0, now.timeIntervalSince(state.dueDate) / 86_400)) / 7
        }
        let weakness =
          tags.reduce(0.0) { $0 + 1 - (states[$1]?.strength ?? 0) } / Double(max(1, tags.count))
        let introduction =
          slot == 2 && chain.ruleIDs.filter({ states[$0]?.lastSeen == nil }).count == 1
          ? weights.introduction : 0
        let overlap = Double(seen.intersection(chain.ruleIDs).count) / Double(max(1, tags.count))
        let variety = chosen.contains { $0.theme == chain.theme } ? 0 : weights.themeVariety
        let replayPenalty = fresh.contains(where: { $0.id == chain.id }) ? 0.0 : 10.0
        return weights.overdue * overdue * (slot == 0 ? 2 : 1) + weights.weakness * weakness
          + introduction - weights.overlap * overlap + variety - replayPenalty
      }
      let introductions =
        slot == 2
        ? pool.filter { $0.ruleIDs.filter({ states[$0]?.lastSeen == nil }).count == 1 } : []
      let candidates = introductions.isEmpty ? pool : introductions
      let ranked = candidates.sorted { a, b in
        let x = score(a)
        let y = score(b)
        if x != y { return x > y }
        let dateA = lastPlayed[a.id] ?? .distantPast
        let dateB = lastPlayed[b.id] ?? .distantPast
        return dateA == dateB ? a.id < b.id : dateA < dateB
      }
      let winner = ranked[0]
      chosen.append(winner)
      pool.removeAll { $0.id == winner.id }
    }
    return chosen
  }
}

public struct PlacementResult: Sendable {
  public var band: CEFR
  public var states: [String: RuleState]
  public var accuracy: Double
  public static func evaluate(results: [(CEFR, StepResult)], now: Date) -> Self {
    var states: [String: RuleState] = [:]
    var band = CEFR.a1
    for candidate in CEFR.allCases {
      let sample = results.filter { $0.0 == candidate }
      if !sample.isEmpty
        && Double(sample.filter { $0.1.firstTryCorrect }.count) / Double(sample.count) >= 0.7
      {
        band = candidate
      }
    }
    for (_, result) in results {
      for id in result.ruleIDs {
        var state = states[id] ?? RuleState(ruleId: id, now: now)
        let correct = !result.failedRuleIDs.contains(id)
        // Repeated observations use the conservative result.
        state.strength = min(state.lastSeen == nil ? 1 : state.strength, correct ? 0.6 : 0.1)
        state.intervalDays = state.strength >= 0.6 ? 3 : 0
        state.dueDate = now.addingTimeInterval(state.intervalDays * 86_400)
        state.lastSeen = now
        state.unlocked = true
        state.attempts += 1
        if correct { state.firstTryCorrect += 1 }
        states[id] = state
      }
    }
    return Self(
      band: band, states: states,
      accuracy: Double(results.filter { $0.1.firstTryCorrect }.count)
        / Double(max(1, results.count)))
  }
}

public enum PracticeDay {
  public static func key(_ date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
  public static func streak(days: [String: Int], now: Date, calendar: Calendar = .current) -> (
    count: Int, freezes: Set<String>
  ) {
    var day = calendar.startOfDay(for: now)
    var count = 0
    var freezes = Set<String>()
    var frozenWeeks = Set<String>()
    if (days[key(day, calendar: calendar)] ?? 0) == 0 {
      day = calendar.date(byAdding: .day, value: -1, to: day)!
    }
    for _ in 0..<4000 {
      let dayKey = key(day, calendar: calendar)
      if (days[dayKey] ?? 0) > 0 {
        count += 1
      } else {
        let week = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
        let weekKey = "\(week.yearForWeekOfYear ?? 0)-\(week.weekOfYear ?? 0)"
        let previous = calendar.date(byAdding: .day, value: -1, to: day)!
        guard !frozenWeeks.contains(weekKey), (days[key(previous, calendar: calendar)] ?? 0) > 0
        else { break }
        frozenWeeks.insert(weekKey)
        freezes.insert(dayKey)
        count += 1
      }
      day = calendar.date(byAdding: .day, value: -1, to: day)!
    }
    return (count, freezes)
  }
}
