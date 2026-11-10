import Foundation

public enum Peel {
  public static func derive(_ chain: Chain) -> Chain {
    let snapshots = [chain.base] + chain.steps.map(\.snapshot)
    var reversed: [Step] = []
    for i in chain.steps.indices.reversed() {
      let original = chain.steps[i]
      let from = snapshots[i + 1]
      let to = snapshots[i]
      let fromIDs = Set(from.tokens.map(\.id))
      let toIDs = Set(to.tokens.map(\.id))
      let added = toIDs.subtracting(fromIDs)
      let removed = fromIDs.subtracting(toIDs)
      let type: CardType =
        !added.isEmpty
        ? .insert
        : !removed.isEmpty ? .delete : original.card.type == .substitute ? .substitute : .transform
      let direct = original.card.directIDs.intersection(toIDs)
      let old = Dictionary(uniqueKeysWithValues: from.tokens.map { ($0.id, $0.text) })
      let fixes = to.tokens.filter {
        old[$0.id] != $0.text && !direct.contains($0.id) && !added.contains($0.id)
      }.map { token in
        Dependency(
          token: token.id, rules: original.rules(for: token.id),
          distractors: [old[token.id]].compactMap { $0 })
      }
      let survivingFrom = from.tokens.map(\.id).filter(toIDs.contains)
      let survivingTo = to.tokens.map(\.id).filter(fromIDs.contains)
      let kept = Set(Validator.lcs(survivingFrom, survivingTo))
      let moves = (survivingTo.filter { !kept.contains($0) } + added.sorted()).map {
        Dependency(token: $0, rules: original.rules(for: $0))
      }
      var slot = "end"
      if let firstAdded = to.tokens.firstIndex(where: { added.contains($0.id) }) {
        if firstAdded == 0 {
          slot = "start"
        } else {
          slot = "after:" + to.tokens[firstAdded - 1].id
        }
      }
      var tokens = to.tokens
      for j in tokens.indices {
        tokens[j].initial = nil
        tokens[j].spawned = nil
      }
      reversed.append(
        Step(
          card: Card(
            type: type, target: original.card.target.flatMap { toIDs.contains($0) ? $0 : nil },
            label: original.inverseLabel,
            cardGloss: ["en": "Undo the last change"], slots: [slot],
            rules: original.ruleIDs.sorted(), appliedTokens: direct.sorted()),
          inverseLabel: original.card.label, tokens: tokens, fixes: fixes, moves: moves,
          gloss: to.gloss,
          noChangeNote: fixes.isEmpty && moves.isEmpty
            ? ["en": "The other words keep their forms."] : nil
        ))
      reversed[reversed.count - 1].terminal = to.terminal
    }
    return Chain(
      chainId: chain.id, cefr: chain.cefr, theme: chain.theme, title: chain.title,
      terminal: chain.terminal, base: chain.final, steps: reversed, lemmas: chain.lemmas)
  }
}

public struct SeededRandom: RandomNumberGenerator, Sendable {
  private var value: UInt64
  public init(seed: String) {
    value = Self.hash(seed)
    if value == 0 { value = 1 }
  }
  public static func hash(_ text: String) -> UInt64 {
    text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
  }
  public mutating func next() -> UInt64 {
    value ^= value << 13
    value ^= value >> 7
    value ^= value << 17
    return value
  }
}

public enum PickerOptions {
  public static func forms(
    tokenID: String, step: Step, current: String, lexicon: [String: Lexeme], seed: String
  ) -> [String] {
    guard let token = step.tokens.first(where: { $0.id == tokenID }) else { return [current] }
    let authored = step.fixes.first { $0.token == tokenID }?.distractors
    let candidates = authored ?? lexicon[token.lemma ?? token.text]?.forms ?? []
    var seen = Set<String>()
    var forms = ([token.text] + candidates).filter {
      seen.insert(Validator.normalized($0)).inserted
    }
    forms = Array(forms.prefix(4))
    var rng = SeededRandom(seed: seed + ":" + tokenID)
    forms.shuffle(using: &rng)
    return forms
  }
}
