import LearningModel
import RippleEngine
import SwiftUI
import UIKit

private struct TokenSelection: Identifiable { let id: String }

struct PracticeView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.legibilityWeight) private var legibilityWeight
  @ScaledMetric(relativeTo: .title2) private var tokenSize = 28.0
  @Namespace private var tokenNamespace
  @State private var selectedToken: TokenSelection?
  @State private var pendingCard = false
  @State private var placingToken: String?
  @State private var showWhy = false
  @State private var showReport = false
  @State private var pulse = false
  @State private var dropMessage: String?
  private var player: ChainPlayer? { store.session?.player }

  var body: some View {
    @Bindable var store = store
    Group {
      if let session = store.session {
        switch session.phase {
        case .playing: playerView(session)
        case .chainSummary: ChainSummaryView()
        case .sessionSummary: SessionSummaryView()
        }
      } else {
        EmptyState(
          symbol: "checkmark.circle", title: "All done", message: "Your progress is saved.",
          actionTitle: "Back to Today"
        ) { store.showPractice = false }
      }
    }.background(Palette.paper)
      .sheet(item: $selectedToken) { selection in
        TokenEditor(
          tokenID: selection.id,
          onPosition: {
            placingToken = selection.id
            selectedToken = nil
          }, onChanged: { autoCheck() }
        )
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showReport) {
        if let player { ReportView(chainID: player.chain.id, step: player.index) }
      }
      .sheet(isPresented: $store.showPaywall) { PaywallView() }
      .onChange(of: player?.index) { _, _ in
        pendingCard = false
        placingToken = nil
        showWhy = false
        dropMessage = nil
      }
  }
  @ViewBuilder private func playerView(_ session: PracticeSession) -> some View {
    let p = session.player
    VStack(spacing: 0) {
      topBar(p)
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            Text(
              session.mode == .demo
                ? "Your first ripple"
                : session.mode == .placement ? "Find your starting point" : session.current.name
            )
            .font(.subheadline.weight(.medium)).foregroundStyle(Palette.secondary)
            Spacer()
            BandBadge(band: session.current.cefr)
          }
          Text(instruction(p, mode: session.mode)).font(.title3.weight(.medium)).fixedSize(
            horizontal: false, vertical: true)
          if typeSize.isAccessibilitySize && p.state.phase == .cardReady { vocabularyGloss(p) }
          sentence(p).padding(.vertical, 14)
          translation(p)
          if p.state.hintLevel == .counted && p.state.phase.isEditable {
            Label(
              "\(p.step.fixes.count) words change · \(p.step.moves.count) moves",
              systemImage: "circle.dotted"
            )
            .font(.subheadline).foregroundStyle(Palette.secondary)
          }
          if !p.state.tokens.filter(\.isSpawnedUnplaced).isEmpty { spawnTray(p) }
          if let dropMessage { Text(dropMessage).font(.subheadline).foregroundStyle(Palette.amber) }
          if p.state.phase != .cardReady { feedback(p) }
          if showWhy { explainers(p) }
        }.padding(24).readingWidth()
      }.scrollBounceBehavior(.basedOnSize)
      tray(p)
    }.accessibilityRotor("Changed words") {
      if p.state.hintLevel == .guided {
        ForEach(p.state.tokens.filter { token in p.step.fixes.contains { $0.token == token.id } }) {
          token in
          AccessibilityRotorEntry(Text(token.text), id: token.id, in: tokenNamespace)
        }
      }
    }
  }
  private func topBar(_ p: ChainPlayer) -> some View {
    HStack(spacing: 12) {
      Button {
        store.pause()
      } label: {
        Image(systemName: "xmark").frame(width: 44, height: 44)
      }.accessibilityLabel("Save and close lesson").accessibilityIdentifier("player.close")
      HStack(spacing: 5) {
        ForEach(p.chain.steps.indices, id: \.self) { i in
          Capsule().fill(
            i < p.index
              ? Palette.accent : i == p.index ? Palette.accent.opacity(0.5) : Palette.subtle
          ).frame(height: 5)
        }
      }.accessibilityLabel("Step \(p.index+1) of \(p.chain.steps.count)")
      Text("L\(p.state.hintLevel.rawValue)").font(.caption.weight(.semibold)).padding(8).background(
        Palette.subtle, in: Capsule()
      )
      .accessibilityLabel("\(p.state.hintLevel.name) help")
      Button {
        showWhy.toggle()
        showReport = false
      } label: {
        Image(systemName: "info.circle").frame(width: 44, height: 44)
      }
      .accessibilityLabel("Rule explanation").contextMenu {
        Button("Report a content problem", systemImage: "flag") { showReport = true }
      }
    }.foregroundStyle(.primary).padding(.horizontal, 12).padding(.top, 8)
  }
  private func instruction(_ p: ChainPlayer, mode: PracticeMode) -> String {
    if p.state.phase.isFinished {
      return p.state.phase == .revealed
        ? "Here’s how it fits together." : "One change. A new sentence."
    }
    if placingToken != nil { return "Choose where the new word goes." }
    if pendingCard {
      return p.step.card.type == .substitute
        ? "Tap the word you want to change." : "Tap a place for your change."
    }
    if p.state.phase == .cardReady {
      return mode == .demo ? "Start with one small change." : "Make the change. Follow the ripple."
    }
    return mode == .demo
      ? "Tap an underlined word. Pick its new form." : "What else needs to change?"
  }
  private func sentence(_ p: ChainPlayer) -> some View {
    FlowLayout(spacing: 7, lineSpacing: 10) {
      if pendingCard && p.step.card.type != .substitute || placingToken != nil { dropZone(0, p: p) }
      ForEach(Array(p.state.sentenceTokens.enumerated()), id: \.element.id) { index, token in
        if !isPunctuation(token.id, p: p) { tokenView(token, index: index, p: p) }
        if pendingCard && p.step.card.type != .substitute || placingToken != nil {
          dropZone(index + 1, p: p)
        }
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 16)
      .dropDestination(for: String.self) { items, _ in
        guard let item = items.first else { return false }
        if item == "ripple-card", p.step.card.type == .transform {
          apply()
          return true
        }
        if item.hasPrefix("ripple-token:") {
          move(String(item.dropFirst(13)), to: p.state.sentenceTokens.count)
          return true
        }
        return false
      }
  }
  private func isPunctuation(_ id: String, p: ChainPlayer) -> Bool {
    (p.step.tokens.first { $0.id == id } ?? p.previous.tokens.first { $0.id == id })?.pos == "PUNCT"
  }
  private func displayText(_ token: TokenState, index: Int, p: ChainPlayer) -> String {
    let tokens = p.state.sentenceTokens
    var text = index == 0 ? token.text.prefix(1).uppercased() + token.text.dropFirst() : token.text
    for next in tokens.dropFirst(index + 1) {
      guard isPunctuation(next.id, p: p) else { break }
      text += next.text
    }
    if tokens.last(where: { !isPunctuation($0.id, p: p) })?.id == token.id {
      text +=
        (p.state.phase == .cardReady ? p.previous.terminal : p.step.terminal) ?? p.chain.terminal
    }
    return text
  }
  private func tokenView(_ token: TokenState, index: Int, p: ChainPlayer) -> some View {
    let stale =
      p.state.hintLevel == .guided && p.state.phase.isEditable
      && p.step.fixes.contains { $0.token == token.id }
      && p.step.tokens.first(where: { $0.id == token.id })?.text != token.text
    let moving =
      p.state.hintLevel == .guided && p.state.phase.isEditable
      && p.step.moves.contains { $0.token == token.id }
      && p.step.tokens.firstIndex(where: { $0.id == token.id })
        != p.state.tokenOrder.firstIndex(of: token.id)
    let wrong = p.state.errors.contains { $0.id == token.id } && p.state.phase == .incorrect
    let cardTarget = pendingCard && p.step.card.target == token.id
    return Button {
      if pendingCard && p.step.card.type == .substitute {
        apply(at: token.id)
      } else if p.state.phase.isEditable {
        selectedToken = TokenSelection(id: token.id)
      } else {
        store.audio.speak(text: token.text, settings: store.settings)
      }
    } label: {
      VStack(spacing: 3) {
        HStack(spacing: 3) {
          Text(displayText(token, index: index, p: p))
            .font(
              .system(
                size: p.state.tokens.count > 14 ? tokenSize * 0.86 : tokenSize,
                weight: legibilityWeight == .bold
                  ? .semibold : p.state.phase == .correct ? .medium : .regular, design: .serif)
            )
            .fixedSize(horizontal: false, vertical: true)
          if moving { Image(systemName: "arrow.left.arrow.right").font(.caption2) }
        }
        if stale || wrong {
          DashedUnderline().stroke(
            style: StrokeStyle(lineWidth: 1.5, dash: wrong ? [2, 2] : [5, 3])
          ).frame(height: 2)
        }
      }.padding(.horizontal, 5).padding(.vertical, 7).frame(minWidth: 44, minHeight: 50)
        .contentShape(Rectangle())
        .foregroundStyle(wrong ? Palette.wrong : stale ? Palette.amber : Palette.ink)
        .background(
          (wrong ? Palette.wrong : cardTarget ? Palette.accent : Color.clear).opacity(
            wrong || cardTarget ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 10))
    }.buttonStyle(.plain)
      .overlay { TokenRipple(active: pulse, index: index) }
      .draggable("ripple-token:\(token.id)")
      .dropDestination(for: String.self) { items, _ in
        guard let item = items.first else { return false }
        if item == "ripple-card" {
          apply(at: p.step.card.type == .substitute ? token.id : slot(index, p: p))
          return true
        }
        if item.hasPrefix("ripple-token:") {
          move(String(item.dropFirst(13)), to: index)
          return true
        }
        return false
      }
      .accessibilityLabel(
        token.text + (stale ? ", needs a new form" : "") + (moving ? ", needs to move" : "")
          + (wrong ? ", check this word" : "")
      )
      .accessibilityValue(cardTarget ? "Change card target" : "")
      .accessibilityHint(
        p.state.phase.isEditable
          ? "Change form. Actions available: move left, move right, hear word." : "Hear this word."
      )
      .accessibilityAction(named: "Move left") { move(token.id, to: max(0, index - 1)) }
      .accessibilityAction(named: "Move right") {
        move(token.id, to: min(p.state.sentenceTokens.count - 1, index + 1))
      }
      .accessibilityAction(named: "Hear word") {
        store.audio.speak(text: token.text, settings: store.settings)
      }
      .accessibilityRotorEntry(id: token.id, in: tokenNamespace)
      .accessibilityIdentifier("token.\(token.id)")
  }
  private func slot(_ index: Int, p: ChainPlayer) -> String {
    let tokens = p.state.sentenceTokens
    if let authored = p.step.card.slots?.first(where: { s in
      if s == "start" { return index == 0 }
      if s == "end" { return index == tokens.count }
      if s.hasPrefix("before:") {
        return tokens.firstIndex { $0.id == String(s.dropFirst(7)) } == index
      }
      if s.hasPrefix("after:"),
        let i = tokens.firstIndex(where: { $0.id == String(s.dropFirst(6)) })
      {
        return i + 1 == index
      }
      return false
    }) {
      return authored
    }
    return index == 0 ? "start" : index == tokens.count ? "end" : "before:" + tokens[index].id
  }
  private func dropZone(_ index: Int, p: ChainPlayer) -> some View {
    let label =
      index == 0
      ? "At the start"
      : index == p.state.sentenceTokens.count
        ? "At the end" : "Before \(p.state.sentenceTokens[index].text)"
    let suggested =
      p.state.hintLevel == .guided && p.step.card.slots?.contains(slot(index, p: p)) == true
      && pendingCard
    return Button {
      if let token = placingToken {
        move(token, to: index)
        placingToken = nil
      } else {
        apply(at: slot(index, p: p))
      }
    } label: {
      Image(systemName: "plus").font(.caption.weight(.bold)).frame(width: 44, height: 44)
        .background(Palette.accent.opacity(suggested ? 0.18 : 0.06), in: Circle()).overlay {
          if suggested {
            Circle().stroke(Palette.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
          }
        }
    }
    .accessibilityLabel("Insert \(label.lowercased())").accessibilityValue(
      suggested ? "Suggested insertion point" : ""
    ).accessibilityIdentifier("slot.\(index)")
  }
  private func translation(_ p: ChainPlayer) -> some View {
    let solved = p.state.phase.isFinished
    let hidden = store.settings.hideTranslation && !solved
    return HStack(alignment: .top, spacing: 12) {
      if hidden {
        TranslationReveal(text: p.previous.gloss["en"] ?? "")
      } else {
        Text((solved ? p.step.gloss["en"] : p.previous.gloss["en"]) ?? "").font(.body)
          .foregroundStyle(Palette.secondary).lineSpacing(4).frame(
            maxWidth: .infinity, alignment: .leading)
      }
      Button {
        store.audio.speak(
          tokens: solved ? p.step.tokens : p.previous.tokens,
          terminal: (solved ? p.step.terminal : p.previous.terminal) ?? p.chain.terminal,
          settings: store.settings)
      } label: {
        Image(systemName: "speaker.wave.2").frame(width: 44, height: 44)
      }.accessibilityLabel("Hear the correct sentence")
    }
  }
  private func spawnTray(_ p: ChainPlayer) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("A new word joins the sentence").font(.subheadline.weight(.medium)).foregroundStyle(
        Palette.amber)
      HStack {
        ForEach(p.state.tokens.filter(\.isSpawnedUnplaced)) { token in
          Button {
            selectedToken = TokenSelection(id: token.id)
          } label: {
            Label(
              token.text == "?" ? "Choose word" : token.text, systemImage: "questionmark.circle"
            ).font(.title3).padding(12).background(
              Palette.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
          }
          .draggable("ripple-token:\(token.id)").accessibilityLabel(
            "New word \(token.text). Choose form and position."
          ).accessibilityIdentifier("spawn.\(token.id)")
        }
      }
    }
  }
  @ViewBuilder private func feedback(_ p: ChainPlayer) -> some View {
    if p.state.phase == .incorrect {
      VStack(alignment: .leading, spacing: 8) {
        Label("Not quite.", systemImage: "arrow.trianglehead.clockwise").font(.headline)
        Text(feedbackText(p)).font(.subheadline).lineSpacing(3)
        Button("Why?") { showWhy.toggle() }.font(.subheadline.weight(.semibold))
      }.foregroundStyle(Palette.wrong).surfaceCard().accessibilityElement(children: .combine)
    } else if p.state.phase.isFinished {
      VStack(alignment: .leading, spacing: 8) {
        Label(
          p.state.phase == .revealed ? "Keep this connection in mind." : "That fits.",
          systemImage: p.state.phase == .revealed ? "lightbulb" : "checkmark.circle.fill"
        ).font(.headline)
        if let note = p.step.noChangeNote?["en"] {
          Text(note).font(.subheadline).foregroundStyle(Palette.secondary)
        }
        if p.state.phase == .revealed {
          Text(feedbackText(p)).font(.subheadline).foregroundStyle(Palette.secondary)
        }
      }.foregroundStyle(p.state.phase == .revealed ? Palette.amber : Palette.success).surfaceCard()
    }
  }
  private func explainers(_ p: ChainPlayer) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      ForEach(store.pack.rules.filter { p.step.ruleIDs.contains($0.id) }) { rule in
        VStack(alignment: .leading, spacing: 7) {
          Text(rule.displayName).font(.subheadline.weight(.semibold))
          Text(rule.explainer["en"] ?? "").font(.subheadline).foregroundStyle(Palette.secondary)
            .lineSpacing(3)
        }
      }
      Button("Report a content problem", systemImage: "flag") { showReport = true }.font(
        .subheadline)
    }.surfaceCard()
  }
  private func feedbackText(_ p: ChainPlayer) -> String {
    let error = p.state.errors.first ?? p.state.firstErrors.first
    let rule =
      error?.rules.compactMap { id in store.pack.rules.first { $0.id == id } }.first
      ?? store.pack.rules.first { p.step.ruleIDs.contains($0.id) }
    let correct = error.flatMap { e in p.step.tokens.first { $0.id == e.id }?.text }
    if error?.kind == .wrongPosition {
      return rule?.explainer["en"] ?? "Move the word into the right position."
    }
    return (rule?.explainer["en"] ?? "Follow the connection between the changed words.")
      + (correct.map { " Here, use “\($0)”." } ?? "")
  }
  private func tray(_ p: ChainPlayer) -> some View {
    VStack(spacing: 14) {
      if p.state.phase == .cardReady {
        Button {
          if p.step.card.type == .transform || p.step.card.type == .delete {
            apply()
          } else {
            pendingCard.toggle()
          }
        } label: {
          HStack(spacing: 14) {
            Image(
              systemName: p.step.card.type == .insert
                ? "plus" : p.step.card.type == .delete ? "minus" : "arrow.left.arrow.right"
            ).font(.title2.weight(.light))
            VStack(alignment: .leading, spacing: 5) {
              Text(p.step.card.label).font(
                typeSize.isAccessibilitySize ? .headline : .title3.weight(.semibold))
              if !typeSize.isAccessibilitySize {
                Text(p.step.card.cardGloss["en"] ?? "Tap to apply").font(.caption).foregroundStyle(
                  Palette.secondary
                ).lineLimit(2)
                vocabularyGloss(p)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.up").font(.body.weight(.semibold))
          }.padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).draggable("ripple-card").accessibilityLabel(cardAccessibilityLabel(p))
          .accessibilityIdentifier("player.card")
        if !typeSize.isAccessibilitySize {
          Text(
            pendingCard
              ? "Choose a word or insertion point above."
              : "Drag the card into the sentence, or tap it."
          ).font(.caption).foregroundStyle(Palette.secondary)
        }
      } else if p.state.phase.isFinished {
        PrimaryButton(
          p.state.phase == .revealed
            ? "Got it · Continue"
            : p.index + 1 == p.chain.steps.count ? "See your sentence" : "Next change",
          symbol: "arrow.right"
        ) { store.nextStep() }
        .accessibilityIdentifier("player.next")
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 12) {
            Button("Nothing changes") { check(nothing: true) }.font(.subheadline.weight(.medium))
              .frame(minHeight: 48)
              .accessibilityIdentifier("player.nothing")
            Spacer(minLength: 0)
            Button {
              store.mutate { $0.reset() }
              Feedback.selection(store.settings)
            } label: {
              Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 48)
            }.accessibilityLabel("Reset this step")
            Button("Check") { check() }.font(.headline).padding(.horizontal, 24).frame(
              minHeight: 48
            ).foregroundStyle(Color("OnAccent")).background(Palette.accent, in: Capsule())
              .accessibilityIdentifier("player.check")
          }
          VStack(spacing: 10) {
            PrimaryButton("Check") { check() }.accessibilityIdentifier("player.check")
            HStack {
              Button("Nothing changes") { check(nothing: true) }.frame(minHeight: 44)
                .accessibilityIdentifier("player.nothing")
              Spacer()
              Button("Reset step") { store.mutate { $0.reset() } }.frame(minHeight: 44)
            }
          }
        }
      }
    }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 16).readingWidth().background(
      Palette.paper)
  }
  private func vocabularyText(_ p: ChainPlayer) -> String? {
    let previous = Dictionary(uniqueKeysWithValues: p.previous.tokens.map { ($0.id, $0.lemma) })
    let lexicon = store.pack.lexiconByLemma
    let newLemmas = p.step.tokens.compactMap { token -> String? in
      guard token.pos != "PUNCT", let lemma = token.lemma,
        previous[token.id] == nil || previous[token.id] != lemma,
        (store.vocabulary[lemma] ?? 0) == 0,
        lexicon[lemma]?.gloss["en"]?.isEmpty == false
      else { return nil }
      return lemma
    }
    let entries = newLemmas.reduce(into: [String]()) { result, lemma in
      let text = "\(lemma): \(lexicon[lemma]?.gloss["en"] ?? "")"
      if !result.contains(text) { result.append(text) }
    }
    return entries.isEmpty ? nil : "New words · " + entries.joined(separator: " · ")
  }
  @ViewBuilder private func vocabularyGloss(_ p: ChainPlayer) -> some View {
    if let text = vocabularyText(p) {
      Text(text)
        .font(.caption).foregroundStyle(Palette.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("card.vocabulary")
    }
  }
  private func cardAccessibilityLabel(_ p: ChainPlayer) -> String {
    let words = typeSize.isAccessibilitySize ? "" : vocabularyText(p).map { " \($0)." } ?? ""
    return "Change card: \(p.step.card.label).\(words) Tap to apply."
  }
  private func apply(at slot: String? = nil) {
    var applied = false
    store.mutate { applied = $0.apply(at: slot) }
    guard applied else {
      dropMessage = "This change belongs elsewhere in the sentence."
      return
    }
    pendingCard = false
    dropMessage = nil
    Feedback.apply(store.settings)
    if let p = player {
      let newRule = p.step.ruleIDs.contains { store.rules[$0]?.lastSeen == nil }
      showWhy = newRule && store.session?.mode != .placement
      UIAccessibility.post(
        notification: .announcement,
        argument: p.state.hintLevel == .guided
          ? "The sentence changed. \(p.step.fixes.count) words need attention."
          : "The sentence changed.")
    }
    if !reduceMotion {
      pulse = true
      Task {
        try? await Task.sleep(for: .milliseconds(300))
        pulse = false
      }
    }
  }
  private func move(_ id: String, to index: Int) {
    store.mutate { $0.move(tokenID: id, to: index) }
    Feedback.selection(store.settings)
    autoCheck()
  }
  private func autoCheck() {
    if player?.canAutoCheck == true {
      selectedToken = nil
      check()
    }
  }
  private func check(nothing: Bool = false) {
    store.mutate { _ = $0.check(nothingChanges: nothing) }
    guard let p = player else { return }
    Feedback.result(p.state.phase == .correct, settings: store.settings)
    if p.state.phase.isFinished && store.settings.autoplay {
      store.audio.speak(
        tokens: p.step.tokens, terminal: p.step.terminal ?? p.chain.terminal,
        settings: store.settings)
    }
    if p.state.phase == .revealed { showWhy = true }
    if p.state.phase.isFinished {
      store.backend.event(
        "step_result",
        [
          "chain_id": p.chain.id, "step": p.index, "hint_level": p.state.hintLevel.rawValue,
          "first_try": p.state.attempts == 1 && p.state.phase == .correct
            && p.state.slotErrors.isEmpty ? 1 : 0, "attempts": p.state.attempts,
          "duration_ms": Int(
            Date.now.timeIntervalSince(store.session?.stepStartedAt ?? .now) * 1000),
          "no_change": p.step.fixes.isEmpty && p.step.moves.isEmpty ? 1 : 0,
        ])
    }
    UIAccessibility.post(
      notification: .announcement,
      argument: p.state.phase == .correct
        ? "That fits. The sentence is correct."
        : p.state.phase == .revealed ? "Here is the correct sentence." : "Not quite. Try again.")
  }
}

private struct DashedUnderline: Shape {
  func path(in rect: CGRect) -> Path {
    Path { p in
      p.move(to: CGPoint(x: 0, y: 1))
      p.addLine(to: CGPoint(x: rect.width, y: 1))
    }
  }
}
private struct TokenRipple: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let active: Bool
  let index: Int
  var body: some View {
    // Only decoration animates; word layout and hit targets remain stationary.
    RoundedRectangle(cornerRadius: 10)
      .stroke(Palette.accent.opacity(active ? 0.3 : 0), lineWidth: 2)
      .scaleEffect(active && !reduceMotion ? 1.06 : 1)
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.15).delay(Double(index) * 0.025), value: active
      )
      .allowsHitTesting(false).accessibilityHidden(true)
  }
}
private struct TranslationReveal: View {
  let text: String
  @State private var shown = false
  var body: some View {
    Button {
      shown.toggle()
    } label: {
      Text(shown ? text : "Tap to reveal the translation").font(.body).foregroundStyle(
        Palette.secondary
      ).frame(maxWidth: .infinity, alignment: .leading)
    }.buttonStyle(.plain).frame(minHeight: 44)
  }
}

private struct TokenEditor: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let tokenID: String
  let onPosition: () -> Void
  let onChanged: () -> Void
  var body: some View {
    NavigationStack {
      if let p = store.session?.player,
        let current = p.state.tokens.first(where: { $0.id == tokenID })
      {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            Text("Choose the form that fits.").font(.title3.weight(.medium))
            if let lemma = p.step.tokens.first(where: { $0.id == tokenID })?.lemma,
              let gloss = store.pack.lexiconByLemma[lemma]?.gloss["en"]
            {
              Text(gloss).font(.subheadline).foregroundStyle(Palette.secondary)
            }
            let forms = PickerOptions.forms(
              tokenID: tokenID, step: p.step, current: current.text,
              lexicon: store.pack.lexiconByLemma,
              seed:
                "\(p.chain.id):\(p.index):\(store.session?.startedAt.timeIntervalSince1970 ?? 0)")
            ForEach(forms, id: \.self) { form in
              Button {
                store.mutate { $0.choose(tokenID: tokenID, form: form) }
                Feedback.selection(store.settings)
                if !current.isSpawnedUnplaced {
                  dismiss()
                  onChanged()
                }
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(form).font(.system(.title2, design: .serif))
                    if p.state.hintLevel == .guided,
                      let lemma = p.step.tokens.first(where: { $0.id == tokenID })?.lemma,
                      let label = store.pack.lexiconByLemma[lemma]?.labels?[form]
                    {
                      Text(label).font(.caption).foregroundStyle(Palette.secondary)
                    }
                  }
                  Spacer()
                  if form == current.text { Image(systemName: "circle.fill").font(.caption) }
                }.padding(16).frame(minHeight: 54).background(
                  Palette.accent.opacity(form == current.text ? 0.12 : 0.05),
                  in: RoundedRectangle(cornerRadius: 14))
              }.buttonStyle(.plain).accessibilityIdentifier("form.\(form)")
            }
            if forms.count == 1 {
              Text("This word doesn’t change.").font(.subheadline).foregroundStyle(
                Palette.secondary)
            }
            Divider()
            if current.isSpawnedUnplaced {
              PrimaryButton(
                "Choose its position", symbol: "arrow.up.and.down.and.arrow.left.and.right"
              ) { onPosition() }
            } else {
              HStack {
                Button("Move left", systemImage: "arrow.left") { reorder(-1, p: p) }.buttonStyle(
                  .bordered
                ).frame(minHeight: 44)
                Spacer()
                Button("Move right", systemImage: "arrow.right") { reorder(1, p: p) }.buttonStyle(
                  .bordered
                ).frame(minHeight: 44)
              }
            }
            Button("Hear this word", systemImage: "speaker.wave.2") {
              store.audio.speak(text: current.text, settings: store.settings)
            }.frame(minHeight: 44)
          }.padding(24)
        }.navigationTitle(current.text == "?" ? "New word" : current.text)
          .navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
          }
      }
    }
  }
  private func reorder(_ delta: Int, p: ChainPlayer) {
    guard let i = p.state.tokenOrder.firstIndex(of: tokenID) else { return }
    store.mutate {
      $0.move(tokenID: tokenID, to: max(0, min(p.state.tokenOrder.count - 1, i + delta)))
    }
    Feedback.selection(store.settings)
    onChanged()
  }
}
