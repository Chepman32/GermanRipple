import Foundation

public enum StepPhase: String, Codable, Sendable {
  case cardReady, fixing, incorrect, correct, revealed
  public var isFinished: Bool { self == .correct || self == .revealed }
  public var isEditable: Bool { self == .fixing || self == .incorrect }
}

public struct TokenState: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public var text: String
  public var isSpawnedUnplaced: Bool
  public init(id: String, text: String, isSpawnedUnplaced: Bool = false) {
    self.id = id
    self.text = text
    self.isSpawnedUnplaced = isSpawnedUnplaced
  }
}

public struct TokenError: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case missing, unexpected, wrongForm, unnecessaryChange, wrongPosition, wrongSlot, falseNoChange
  }
  public var id: String
  public var kind: Kind
  public var rules: [String]
  public init(id: String, kind: Kind, rules: [String]) {
    self.id = id
    self.kind = kind
    self.rules = rules
  }
}

public struct StepState: Codable, Equatable, Sendable {
  public var phase: StepPhase = .cardReady
  public var tokens: [TokenState]
  public var hintLevel: HintLevel
  public var attempts: Int = 0
  public var errors: [TokenError] = []
  public var firstErrors: [TokenError] = []
  public var slotErrors: Set<String> = []
  public var tokenOrder: [String] { tokens.filter { !$0.isSpawnedUnplaced }.map(\.id) }
  public var sentenceTokens: [TokenState] { tokens.filter { !$0.isSpawnedUnplaced } }
  public init(tokens: [TokenState], hintLevel: HintLevel) {
    self.tokens = tokens
    self.hintLevel = hintLevel
  }
}

public enum Validator {
  public static func normalized(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  public static func errors(state: StepState, target: Step) -> [TokenError] {
    var errors: [TokenError] = []
    let expectedIDs = Set(target.tokens.map(\.id))
    for token in target.tokens {
      guard let current = state.tokens.first(where: { $0.id == token.id }),
        !current.isSpawnedUnplaced
      else {
        errors.append(TokenError(id: token.id, kind: .missing, rules: target.rules(for: token.id)))
        continue
      }
      let currentText = normalized(current.text)
      let expectedText = normalized(token.text)
      let initialCapital =
        token.id == state.tokenOrder.first && expectedText.first?.isLowercase == true
        && currentText == expectedText.prefix(1).uppercased() + expectedText.dropFirst()
      if currentText != expectedText && !initialCapital {
        let stale = target.fixes.contains { $0.token == token.id }
        errors.append(
          TokenError(
            id: token.id, kind: stale ? .wrongForm : .unnecessaryChange,
            rules: target.rules(for: token.id)))
      }
    }
    for token in state.tokens where !expectedIDs.contains(token.id) {
      errors.append(TokenError(id: token.id, kind: .unexpected, rules: target.ruleIDs.sorted()))
    }
    let order = state.tokenOrder
    if target.acceptedOrders.isEmpty {
      errors.append(TokenError(id: "order", kind: .wrongPosition, rules: target.ruleIDs.sorted()))
    }
    if !target.acceptedOrders.contains(order) {
      let closest =
        target.acceptedOrders.max { lcs(order, $0).count < lcs(order, $1).count }
        ?? target.tokens.map(\.id)
      let kept = Set(lcs(order, closest))
      for id in order where expectedIDs.contains(id) && !kept.contains(id) {
        errors.append(TokenError(id: id, kind: .wrongPosition, rules: target.orderRules(for: id)))
      }
      // Duplicates must never accidentally validate as a set match.
      if Set(order).count != order.count {
        errors.append(TokenError(id: "order", kind: .wrongPosition, rules: target.ruleIDs.sorted()))
      }
    }
    return errors
  }
  public static func lcs(_ a: [String], _ b: [String]) -> [String] {
    var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    if !a.isEmpty && !b.isEmpty {
      for i in 1...a.count {
        for j in 1...b.count {
          table[i][j] =
            a[i - 1] == b[j - 1] ? table[i - 1][j - 1] + 1 : max(table[i - 1][j], table[i][j - 1])
        }
      }
    }
    var i = a.count
    var j = b.count
    var result: [String] = []
    while i > 0 && j > 0 {
      if a[i - 1] == b[j - 1] {
        result.append(a[i - 1])
        i -= 1
        j -= 1
      } else if table[i - 1][j] >= table[i][j - 1] {
        i -= 1
      } else {
        j -= 1
      }
    }
    return result.reversed()
  }
}

public struct StepResult: Codable, Equatable, Sendable {
  public var index: Int
  public var hintLevel: HintLevel
  public var attempts: Int
  public var revealed: Bool
  public var ruleIDs: [String]
  public var failedRuleIDs: Set<String>
  public var firstTryCorrect: Bool { attempts == 1 && !revealed && failedRuleIDs.isEmpty }
}

public struct ChainPlayer: Codable, Sendable {
  public let chain: Chain
  public private(set) var index: Int = 0
  public private(set) var state: StepState
  public private(set) var results: [StepResult] = []
  public private(set) var isComplete = false
  private var appliedState: [TokenState] = []
  public var step: Step { chain.steps[index] }
  public var previous: Snapshot { index == 0 ? chain.base : chain.steps[index - 1].snapshot }

  public init(chain: Chain, hintLevel: HintLevel = .guided) {
    self.chain = chain
    state = StepState(
      tokens: chain.base.tokens.map { TokenState(id: $0.id, text: $0.text) }, hintLevel: hintLevel)
    isComplete = chain.steps.isEmpty
  }

  @discardableResult public mutating func apply(at destination: String? = nil) -> Bool {
    guard !isComplete, state.phase == .cardReady else { return false }
    if step.card.type == .insert, let destination, let slots = step.card.slots,
      !slots.contains(destination)
    {
      if step.card.slotIsTrained == true { state.slotErrors.formUnion(step.card.rules) }
      return false
    }
    if step.card.type == .substitute, let destination, let target = step.card.target,
      destination != target
    {
      if step.card.slotIsTrained == true { state.slotErrors.formUnion(step.card.rules) }
      return false
    }
    let targetIDs = Set(step.tokens.map(\.id))
    let oldIDs = Set(previous.tokens.map(\.id))
    var existing = state.tokens.filter { targetIDs.contains($0.id) }
    let targetByID = Dictionary(uniqueKeysWithValues: step.tokens.map { ($0.id, $0) })
    for i in existing.indices where step.card.directIDs.contains(existing[i].id) {
      existing[i].text =
        targetByID[existing[i].id]?.initial ?? targetByID[existing[i].id]?.text ?? existing[i].text
    }
    var added = step.tokens.filter { !oldIDs.contains($0.id) }
    if let initialOrder = step.initialOrderOfInserted {
      added.sort {
        (initialOrder.firstIndex(of: $0.id) ?? Int.max)
          < (initialOrder.firstIndex(of: $1.id) ?? Int.max)
      }
    }
    let placed = added.filter { $0.spawned != true }.map { token in
      TokenState(
        id: token.id,
        text: token.initial
          ?? (step.fixes.contains(where: { $0.token == token.id })
            ? token.lemma ?? token.text : token.text))
    }
    let slot = destination ?? step.card.slots?.first ?? "end"
    let insertionIndex: Int
    if slot == "start" {
      insertionIndex = 0
    } else if slot.hasPrefix("before:"),
      let i = existing.firstIndex(where: { $0.id == String(slot.dropFirst(7)) })
    {
      insertionIndex = i
    } else if slot.hasPrefix("after:"),
      let i = existing.firstIndex(where: { $0.id == String(slot.dropFirst(6)) })
    {
      insertionIndex = i + 1
    } else {
      insertionIndex = existing.count
    }
    existing.insert(contentsOf: placed, at: insertionIndex)
    existing += added.filter { $0.spawned == true }.map {
      TokenState(id: $0.id, text: "?", isSpawnedUnplaced: true)
    }
    state.tokens = existing
    state.phase = .fixing
    appliedState = existing
    return true
  }

  public mutating func choose(tokenID: String, form: String) {
    guard state.phase.isEditable, let i = state.tokens.firstIndex(where: { $0.id == tokenID })
    else { return }
    state.tokens[i].text = form
    state.errors.removeAll { $0.id == tokenID }
    state.phase = .fixing
  }
  public mutating func move(tokenID: String, to position: Int) {
    guard state.phase.isEditable, let i = state.tokens.firstIndex(where: { $0.id == tokenID })
    else { return }
    var token = state.tokens.remove(at: i)
    token.isSpawnedUnplaced = false
    state.tokens.insert(token, at: max(0, min(position, state.sentenceTokens.count)))
    state.errors.removeAll { $0.id == tokenID }
    state.phase = .fixing
  }
  public mutating func reset() {
    guard state.phase.isEditable else { return }
    state.tokens = appliedState
    state.errors = []
    state.phase = .fixing
  }
  public var canAutoCheck: Bool {
    state.phase.isEditable && state.hintLevel == .guided
      && (!step.fixes.isEmpty || !step.moves.isEmpty)
      && Validator.errors(state: state, target: step).isEmpty
  }
  @discardableResult public mutating func check(nothingChanges: Bool = false) -> Bool {
    guard state.phase.isEditable else { return false }
    var errors = Validator.errors(state: state, target: step)
    if nothingChanges {
      var applied = state
      applied.tokens = appliedState
      if !Validator.errors(state: applied, target: step).isEmpty {
        errors.append(
          TokenError(id: "decision", kind: .falseNoChange, rules: step.ruleIDs.sorted()))
      }
    }
    state.attempts += 1
    if state.attempts == 1 { state.firstErrors = errors }
    state.errors = errors
    if errors.isEmpty {
      state.phase = .correct
      return true
    }
    if state.attempts >= 2 { reveal() } else { state.phase = .incorrect }
    return false
  }
  private mutating func reveal() {
    state.tokens = step.tokens.map { TokenState(id: $0.id, text: $0.text) }
    state.phase = .revealed
  }
  /// Returns false at the end of the chain. A finished step can only be committed once.
  @discardableResult public mutating func advance(hintLevel: HintLevel = .guided) -> Bool {
    guard !isComplete, state.phase.isFinished else { return false }
    let failed = Set(state.firstErrors.flatMap(\.rules)).union(state.slotErrors)
    results.append(
      StepResult(
        index: index, hintLevel: state.hintLevel, attempts: state.attempts,
        revealed: state.phase == .revealed, ruleIDs: step.ruleIDs.sorted(), failedRuleIDs: failed))
    if index + 1 == chain.steps.count {
      isComplete = true
      return false
    }
    let snapshot = step.snapshot
    index += 1
    state = StepState(
      tokens: snapshot.tokens.map { TokenState(id: $0.id, text: $0.text) }, hintLevel: hintLevel)
    return true
  }
}
