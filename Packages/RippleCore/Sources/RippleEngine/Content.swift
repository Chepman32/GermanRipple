import Foundation

public enum CEFR: String, Codable, CaseIterable, Comparable, Sendable {
  case a1 = "A1"
  case a2 = "A2"
  case b1 = "B1"
  public static func < (lhs: Self, rhs: Self) -> Bool {
    allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
  }
}

public enum CardType: String, Codable, Sendable {
  case substitute = "SUBSTITUTE"
  case insert = "INSERT"
  case delete = "DELETE"
  case transform = "TRANSFORM"
}

public enum HintLevel: Int, Codable, Sendable {
  case guided = 1
  case counted = 2
  case free = 3
  public var name: String {
    switch self {
    case .guided: "Guided"
    case .counted: "Counted"
    case .free: "Free"
    }
  }
}

public struct Token: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public var text: String
  public var lemma: String?
  public var pos: String
  public var initial: String?
  public var spawned: Bool?
  public var ipa: String?

  public init(
    id: String, text: String, lemma: String? = nil, pos: String = "X", initial: String? = nil,
    spawned: Bool? = nil, ipa: String? = nil
  ) {
    self.id = id
    self.text = text
    self.lemma = lemma
    self.pos = pos
    self.initial = initial
    self.spawned = spawned
    self.ipa = ipa
  }
}

public struct Snapshot: Codable, Equatable, Sendable {
  public var tokens: [Token]
  public var gloss: [String: String]
  public var terminal: String?
  public init(tokens: [Token], gloss: [String: String] = [:], terminal: String? = nil) {
    self.tokens = tokens
    self.gloss = gloss
    self.terminal = terminal
  }
}

public struct Card: Codable, Equatable, Sendable {
  public var type: CardType
  public var target: String?
  public var label: String
  public var cardGloss: [String: String]
  public var slots: [String]?
  public var slotIsTrained: Bool?
  public var rules: [String]
  /// IDs changed by the card itself, rather than by the learner.
  public var appliedTokens: [String]?

  public init(
    type: CardType, target: String? = nil, label: String, cardGloss: [String: String] = [:],
    slots: [String]? = nil, slotIsTrained: Bool = false, rules: [String] = [],
    appliedTokens: [String]? = nil
  ) {
    self.type = type
    self.target = target
    self.label = label
    self.cardGloss = cardGloss
    self.slots = slots
    self.slotIsTrained = slotIsTrained
    self.rules = rules
    self.appliedTokens = appliedTokens
  }
  public var directIDs: Set<String> { Set(appliedTokens ?? target.map { [$0] } ?? []) }
}

public struct Dependency: Codable, Equatable, Sendable {
  public var token: String
  public var rules: [String]
  public var distractors: [String]?
  public init(token: String, rules: [String], distractors: [String]? = nil) {
    self.token = token
    self.rules = rules
    self.distractors = distractors
  }
}

public struct Step: Codable, Equatable, Sendable {
  public var card: Card
  public var inverseLabel: String
  public var tokens: [Token]
  public var fixes: [Dependency]
  public var moves: [Dependency]
  public var acceptedOrders: [[String]]
  public var gloss: [String: String]
  public var noChangeNote: [String: String]?
  public var initialOrderOfInserted: [String]?
  public var terminal: String?

  public init(
    card: Card, inverseLabel: String, tokens: [Token], fixes: [Dependency] = [],
    moves: [Dependency] = [], acceptedOrders: [[String]]? = nil, gloss: [String: String] = [:],
    noChangeNote: [String: String]? = nil, initialOrderOfInserted: [String]? = nil
  ) {
    self.card = card
    self.inverseLabel = inverseLabel
    self.tokens = tokens
    self.fixes = fixes
    self.moves = moves
    self.acceptedOrders = acceptedOrders ?? [tokens.map(\.id)]
    self.gloss = gloss
    self.noChangeNote = noChangeNote
    self.initialOrderOfInserted = initialOrderOfInserted
  }
  public var ruleIDs: Set<String> { Set(card.rules + (fixes + moves).flatMap(\.rules)) }
  public var snapshot: Snapshot { Snapshot(tokens: tokens, gloss: gloss, terminal: terminal) }
  public func rules(for id: String) -> [String] {
    let specific = (fixes + moves).filter { $0.token == id }.flatMap(\.rules)
    return specific.isEmpty ? ruleIDs.sorted() : Array(Set(specific)).sorted()
  }
  public func orderRules(for id: String) -> [String] {
    let specific = moves.filter { $0.token == id }.flatMap(\.rules)
    let all = specific.isEmpty ? moves.flatMap(\.rules) : specific
    return all.isEmpty ? ruleIDs.sorted() : Set(all).sorted()
  }
}

public struct Chain: Codable, Identifiable, Equatable, Sendable {
  public var chainId: String
  public var cefr: CEFR
  public var theme: String
  public var title: [String: String]
  public var terminal: String
  public var base: Snapshot
  public var steps: [Step]
  public var lemmas: [String]?
  public var id: String { chainId }
  public var name: String { title["en"] ?? chainId }
  public var ruleIDs: Set<String> { steps.reduce(into: Set<String>()) { $0.formUnion($1.ruleIDs) } }
  public var final: Snapshot { steps.last?.snapshot ?? base }
  public init(
    chainId: String, cefr: CEFR = .a1, theme: String = "cafe", title: [String: String] = [:],
    terminal: String = ".", base: Snapshot, steps: [Step], lemmas: [String]? = nil
  ) {
    self.chainId = chainId
    self.cefr = cefr
    self.theme = theme
    self.title = title
    self.terminal = terminal
    self.base = base
    self.steps = steps
    self.lemmas = lemmas
  }
}

public struct Rule: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var category: String
  public var cefr: CEFR
  public var name: [String: String]
  public var prerequisites: [String]
  public var explainer: [String: String]
  public var feedbackTemplate: [String: String]?
  public var table: [[String]]?
  public var displayName: String { name["en"] ?? id }
  public init(
    id: String, category: String, cefr: CEFR, name: String, prerequisites: [String] = [],
    explainer: String, table: [[String]]? = nil
  ) {
    self.id = id
    self.category = category
    self.cefr = cefr
    self.name = ["en": name]
    self.prerequisites = prerequisites
    self.explainer = ["en": explainer]
    self.table = table
  }
}

public struct Lexeme: Codable, Equatable, Sendable {
  public var lemma: String
  public var cefr: CEFR
  public var forms: [String]
  public var gloss: [String: String]
  public var labels: [String: String]?
  public init(lemma: String, cefr: CEFR = .a1, forms: [String], gloss: [String: String] = [:]) {
    self.lemma = lemma
    self.cefr = cefr
    self.forms = forms
    self.gloss = gloss
  }
}

public enum Sentence {
  public static func text(_ tokens: [Token], terminal: String = ".") -> String {
    text(tokens.map(\.text), terminal: terminal)
  }
  public static func text(_ words: [String], terminal: String = ".") -> String {
    var result = ""
    for word in words {
      if [",", ".", "!", "?", ";", ":"].contains(word) {
        result += word
      } else {
        result += (result.isEmpty ? "" : " ") + word
      }
    }
    if let first = result.first { result = first.uppercased() + result.dropFirst() }
    if !result.isEmpty && ![".", "!", "?"].contains(String(result.suffix(1))) {
      result += terminal
    }
    return result
  }
  public static func wordCount(_ tokens: [Token]) -> Int {
    tokens.filter { $0.pos != "PUNCT" }.count
  }
}
