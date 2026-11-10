import Foundation
import Testing

@testable import ContentKit
@testable import LearningModel
@testable import RippleEngine
@testable import SyncKit

func fixture() throws -> ContentPack {
  var root = URL(fileURLWithPath: #filePath)
  for _ in 0..<5 { root.deleteLastPathComponent() }
  return try ContentPack.decode(
    Data(contentsOf: root.appendingPathComponent("content/source/pack.json")))
}

@Suite("Authored content and deterministic engine") struct EngineTests {
  @Test func expandedVocabularyIsUsedAndSentenceVarietyIsPreserved() throws {
    let pack = try fixture()
    let observed = Set(pack.chains.flatMap { chain in
      ([chain.base] + chain.steps.map(\.snapshot)).flatMap(\.tokens)
        .filter { $0.pos != "PUNCT" }.map { $0.lemma ?? $0.text }
    })
    #expect(observed == Set(pack.lexicon.map(\.lemma)))
    #expect((850...1_000).contains(observed.count))
    #expect(!observed.contains("würden"))
    #expect(!observed.contains("Stühle"))
    #expect(Set(pack.chains.map { Sentence.text($0.base.tokens) }).count >= 235)
    #expect(Set(pack.chains.map { Sentence.text($0.final.tokens) }).count == 240)
    #expect(pack.chains.allSatisfy { Sentence.wordCount($0.final.tokens) <= 22 })
  }
  @Test func wholeCatalogValidatesAndSolvesInBothDirections() throws {
    let pack = try fixture()
    #expect(pack.chains.count == 240)
    #expect(pack.rules.count == 51)
    for original in pack.chains {
      for chain in [original, Peel.derive(original)] {
        var player = ChainPlayer(chain: chain, hintLevel: .free)
        for target in chain.steps {
          let applied = player.apply()
          #expect(applied)
          for token in target.tokens { player.choose(tokenID: token.id, form: token.text) }
          for (i, token) in target.tokens.enumerated() { player.move(tokenID: token.id, to: i) }
          #expect(
            Validator.errors(state: player.state, target: target).isEmpty,
            "\(chain.id)/\(player.index)")
          let correct = player.check()
          #expect(correct)
          player.advance(hintLevel: .free)
        }
        #expect(player.isComplete)
        #expect(player.results.count == chain.steps.count)
        #expect(player.results.allSatisfy { $0.firstTryCorrect })
        let advanced = player.advance()
        #expect(!advanced)
      }
    }
  }
  @Test func everyDependencyCanBeReachedFromCardState() throws {
    for chain in try fixture().chains {
      var player = ChainPlayer(chain: chain)
      for target in chain.steps {
        player.apply()
        for token in target.tokens where target.fixes.contains(where: { $0.token == token.id }) {
          player.choose(tokenID: token.id, form: token.text)
        }
        // Every required reordering must be declared, including spawned placement.
        for id in target.tokens.map(\.id).filter({ id in target.moves.contains { $0.token == id } })
        {
          player.move(tokenID: id, to: target.tokens.firstIndex { $0.id == id }!)
        }
        #expect(
          Validator.errors(state: player.state, target: target).isEmpty,
          "Undeclared dependency: \(chain.id)/\(player.index)")
        for (i, token) in target.tokens.enumerated() {
          player.choose(tokenID: token.id, form: token.text)
          player.move(tokenID: token.id, to: i)
        }
        player.check()
        player.advance()
      }
    }
  }
  @Test func substituteDropsUseTargetRatherThanInsertionSlot() throws {
    for chain in try fixture().chains {
      var player = ChainPlayer(chain: chain)
      for step in chain.steps {
        let destination = step.card.type == .substitute ? step.card.target : step.card.slots?.first
        let applied = player.apply(at: destination)
        #expect(
          applied,
          "Card could not be applied to its authored destination: \(chain.id)/\(player.index)")
        for (i, token) in step.tokens.enumerated() {
          player.choose(tokenID: token.id, form: token.text)
          player.move(tokenID: token.id, to: i)
        }
        player.check()
        player.advance()
      }
    }
  }
  @Test func twoErrorsRevealAndResetDoesNotEraseFirstTry() throws {
    var p = ChainPlayer(chain: try fixture().chains[0])
    p.apply()
    let first = p.check()
    #expect(!first)
    #expect(p.state.phase == .incorrect)
    p.reset()
    #expect(p.state.attempts == 1)
    let second = p.check()
    #expect(!second)
    #expect(p.state.phase == .revealed)
    #expect(Validator.errors(state: p.state, target: p.step).isEmpty)
    p.advance()
    #expect(!p.results[0].firstTryCorrect)
    #expect(!p.results[0].failedRuleIDs.isEmpty)
  }
  @Test func wrongFormExtraMissingAndOrderAreRejected() throws {
    let chain = try fixture().chains[0]
    let step = chain.steps[0]
    var s = StepState(
      tokens: step.tokens.map { TokenState(id: $0.id, text: $0.text) }, hintLevel: .free)
    #expect(Validator.errors(state: s, target: step).isEmpty)
    s.tokens[1].text = "wrong"
    #expect(Validator.errors(state: s, target: step).contains { $0.kind == .wrongForm })
    s.tokens[0].text = "wrong"
    #expect(Validator.errors(state: s, target: step).contains { $0.kind == .unnecessaryChange })
    s.tokens.removeLast()
    #expect(Validator.errors(state: s, target: step).contains { $0.kind == .missing })
    s.tokens.append(.init(id: "extra", text: "extra"))
    #expect(Validator.errors(state: s, target: step).contains { $0.kind == .unexpected })
    s.tokens.reverse()
    #expect(Validator.errors(state: s, target: step).contains { $0.kind == .wrongPosition })
  }
  @Test func unicodeAndCapitalizationArePrecise() {
    let target = Step(
      card: Card(type: .transform, label: ""), inverseLabel: "",
      tokens: [Token(id: "s", text: "wir"), Token(id: "n", text: "Mädchen")])
    var state = StepState(
      tokens: [.init(id: "s", text: "Wir"), .init(id: "n", text: "Ma\u{0308}dchen")],
      hintLevel: .free)
    #expect(Validator.errors(state: state, target: target).isEmpty)
    state.tokens[1].text = "mädchen"
    #expect(!Validator.errors(state: state, target: target).isEmpty)
    #expect(
      Sentence.text(["wir", "gehen", ",", "weil", "es", "regnet"]) == "Wir gehen, weil es regnet.")
  }
  @Test func pickerIsStableAcrossRetriesAndIncludesAnswer() throws {
    let pack = try fixture()
    let step = pack.chains[0].steps[0]
    let a = PickerOptions.forms(
      tokenID: "v", step: step, current: "kaufe", lexicon: pack.lexiconByLemma, seed: "123")
    let b = PickerOptions.forms(
      tokenID: "v", step: step, current: "wrong", lexicon: pack.lexiconByLemma, seed: "123")
    #expect(a == b)
    #expect(a.contains("kaufst"))
    #expect(Set(a).count == a.count)
  }
  @Test func nothingChangesDecisionCannotBypassFixes() throws {
    var p = ChainPlayer(chain: try fixture().chains[0])
    p.apply()
    let decision = p.check(nothingChanges: true)
    #expect(!decision)
    #expect(p.state.errors.contains { $0.kind == .falseNoChange })
  }
  @Test func checkpointRoundTripPreservesRetryState() throws {
    var p = ChainPlayer(chain: try fixture().chains[0])
    p.apply()
    p.check()
    var restored = try JSONDecoder().decode(ChainPlayer.self, from: JSONEncoder().encode(p))
    restored.reset()
    #expect(restored.state.attempts == 1)
    let checked = restored.check()
    #expect(!checked)
    #expect(restored.state.phase == .revealed)
  }
  @Test func acceptedAlternativeOrdersAreHonored() {
    let tokens = [Token(id: "a", text: "a"), Token(id: "b", text: "b")]
    let step = Step(
      card: Card(type: .transform, label: ""), inverseLabel: "", tokens: tokens,
      acceptedOrders: [["a", "b"], ["b", "a"]])
    let state = StepState(
      tokens: [.init(id: "b", text: "b"), .init(id: "a", text: "a")], hintLevel: .free)
    #expect(Validator.errors(state: state, target: step).isEmpty)
  }
  @Test func duplicatedWordsAndInvalidTargetsNeverValidate() {
    let tokens = [Token(id: "a", text: "a"), Token(id: "b", text: "b"), Token(id: "c", text: "c")]
    var step = Step(
      card: Card(type: .transform, label: ""), inverseLabel: "", tokens: tokens,
      acceptedOrders: [["a", "b", "c"], ["b", "a", "c"]])
    var state = StepState(
      tokens: [.init(id: "b", text: "b"), .init(id: "c", text: "c"), .init(id: "a", text: "a")],
      hintLevel: .free)
    #expect(!Validator.errors(state: state, target: step).isEmpty)
    state.tokens = [
      .init(id: "a", text: "a"), .init(id: "b", text: "b"), .init(id: "c", text: "c"),
      .init(id: "a", text: "a"),
    ]
    #expect(Validator.errors(state: state, target: step).contains { $0.id == "order" })
    step.acceptedOrders = []
    state.tokens.removeLast()
    #expect(!Validator.errors(state: state, target: step).isEmpty)
  }
  @Test func movementErrorsKeepTheirOwnRuleAttribution() {
    let tokens = [
      Token(id: "s", text: "wir"), Token(id: "v", text: "lernen"), Token(id: "n", text: "Deutsch"),
    ]
    let step = Step(
      card: Card(type: .insert, label: ""), inverseLabel: "", tokens: tokens,
      fixes: [Dependency(token: "v", rules: ["verb.present.regular"])],
      moves: [Dependency(token: "v", rules: ["order.v2-inversion"])])
    let state = StepState(
      tokens: [
        .init(id: "v", text: "lernen"), .init(id: "s", text: "wir"),
        .init(id: "n", text: "Deutsch"),
      ], hintLevel: .guided)
    let errors = Validator.errors(state: state, target: step).filter { $0.kind == .wrongPosition }
    #expect(!errors.isEmpty)
    #expect(errors.allSatisfy { $0.rules == ["order.v2-inversion"] })
  }
}

@Suite("Learning and scheduling") struct LearningTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  @Test func updateMathAndFirstEncounter() {
    var s = RuleState(ruleId: "r", now: now)
    s.update(correct: false, now: now, hintLevel: .guided, chainID: "c", firstEncounter: true)
    #expect(s.attempts == 0)
    #expect(s.strength == 0)
    s.update(correct: true, now: now, hintLevel: .guided, chainID: "c")
    #expect(s.strength == 0.25)
    #expect(s.intervalDays == 1)
    #expect(s.hintLevel == .guided)
    s.update(correct: true, now: now, hintLevel: .guided, chainID: "c")
    #expect(s.strength == 0.4375)
    #expect(s.intervalDays == 2.2)
    #expect(s.hintLevel == .counted)
    s.update(correct: false, now: now, hintLevel: .counted, chainID: "c")
    #expect(abs(s.strength - 0.2625) < 0.00001)
    #expect(s.intervalDays == 1)
  }
  @Test func masteryRequiresThreeDifferentUnaidedChains() {
    var s = RuleState(ruleId: "r", now: now)
    for _ in 0..<20 { s.update(correct: true, now: now, hintLevel: .free, chainID: "same") }
    #expect(!s.mastered)
    #expect(s.intervalDays == 60)
    for id in ["two", "three"] { s.update(correct: true, now: now, hintLevel: .free, chainID: id) }
    #expect(s.mastered)
  }
  @Test func initialSchedulerIsDeterministicAndNonempty() throws {
    let p = try fixture()
    var states: [String: RuleState] = [:]
    UnlockGraph.refresh(rules: p.rules, states: &states, now: now)
    let s = Scheduler()
    let a = s.select(
      chains: p.chains, rules: p.rules, states: states, history: [], band: .a1, now: now)
    let b = s.select(
      chains: p.chains.reversed(), rules: p.rules, states: states, history: [], band: .a1, now: now)
    #expect(a.map(\.id) == b.map(\.id))
    #expect(a.count == 3)
    #expect(Set(a.map(\.id)).count == 3)
    let replay = s.select(
      chains: p.chains, rules: p.rules, states: states,
      history: a.map { .init(chainID: $0.id, completedAt: now) }, band: .a1, now: now)
    #expect(Set(a.map(\.id)).isDisjoint(with: Set(replay.map(\.id))))
  }
  @Test func firstEncounterForcesGuidanceAndPrerequisitesUnlock() throws {
    let p = try fixture()
    let step = p.chains[0].steps[0]
    #expect(UnlockGraph.hintLevel(for: step, states: [:]) == .guided)
    let rule = p.rules.first { $0.id == "adj.decl.mixed" }!
    var prereq = RuleState(ruleId: "article.indef.acc", now: now)
    prereq.strength = 0.4
    #expect(!UnlockGraph.available(rule: rule, states: [:]))
    #expect(UnlockGraph.available(rule: rule, states: [prereq.ruleId: prereq]))
  }
  @Test func oneFreezePerCalendarWeek() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = cal.date(from: DateComponents(year: 2026, month: 11, day: 7))!
    let s = PracticeDay.streak(
      days: ["2026-11-07": 1, "2026-11-05": 1, "2026-11-03": 1], now: today, calendar: cal)
    #expect(s.count == 3)
    #expect(s.freezes == ["2026-11-06"])
  }
}

@Suite("Conflict-free progress") struct MergeTests {
  @Test func mergeIsCommutativeIdempotentAndKeepsLatest() throws {
    var r = RuleState(ruleId: "r", now: .distantPast)
    r.lastSeen = Date(timeIntervalSince1970: 100)
    r.strength = 0.4
    var later = r
    later.lastSeen = Date(timeIntervalSince1970: 200)
    later.strength = 0.2
    let c = SyncedCompletion(
      chainID: "c", completedAt: Date(timeIntervalSince1970: 100), mode: "forward", firstTryRate: 1,
      durationSeconds: 90)
    let a = ProgressSnapshot(rules: ["r": r], chains: [c], streak: ["2026-11-07": 1])
    let b = ProgressSnapshot(rules: ["r": later], chains: [c], streak: ["2026-11-07": 3])
    let merged = ProgressSnapshot.merge(a, b)
    #expect(merged == ProgressSnapshot.merge(b, a))
    #expect(merged == ProgressSnapshot.merge(merged, merged))
    #expect(merged.rules["r"]?.strength == 0.2)
    #expect(merged.chains.count == 1)
    #expect(merged.streak["2026-11-07"] == 3)
    _ = try merged.validated()
  }
  @Test func tiesResolveDeterministicallyAndInvalidRemoteIsRejected() throws {
    var r = RuleState(ruleId: "r", now: .now)
    var s = r
    r.strength = 0.5
    s.strength = 0.2
    let a = ProgressSnapshot(rules: ["r": r])
    let b = ProgressSnapshot(rules: ["r": s])
    #expect(ProgressSnapshot.merge(a, b) == ProgressSnapshot.merge(b, a))
    r.strength = Double.nan
    #expect(throws: SyncError.self) { try ProgressSnapshot(rules: ["r": r]).validated() }
  }
}
