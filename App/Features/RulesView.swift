import Charts
import RippleEngine
import SwiftUI

struct RulesView: View {
  @Environment(AppStore.self) private var store
  @State private var band = "All"
  private var categories: [String] {
    ["Verbs", "Word order", "Articles & adjectives", "Cases & pronouns", "Clauses"]
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Make the connections.").font(.system(.title, design: .serif, weight: .medium))
          Text("Every ripple strengthens a rule. Your map grows with you.").font(.subheadline)
            .foregroundStyle(Palette.secondary)
        }
        Picker("Level", selection: $band) {
          ForEach(["All", "A1", "A2", "B1"], id: \.self) { Text($0).tag($0) }
        }.pickerStyle(.segmented)
        HStack {
          Label(
            "\(store.rules.values.filter(\.mastered).count) mastered", systemImage: "checkmark.seal"
          ).font(.subheadline)
          Spacer()
          Text("\(store.pack.rules.count) connections").font(.subheadline).foregroundStyle(
            Palette.secondary)
        }
        ForEach(categories, id: \.self) { category in
          let selected = store.pack.rules.filter {
            $0.category == category && (band == "All" || $0.cefr.rawValue == band)
          }
          if !selected.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
              Text(category).font(.title3.weight(.semibold))
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .top)], spacing: 12)
              {
                ForEach(selected) { rule in
                  NavigationLink {
                    RuleDetailView(rule: rule)
                  } label: {
                    RuleTile(rule: rule)
                  }.buttonStyle(.plain)
                }
              }
            }
          }
        }
      }.padding(24).readingWidth()
    }.background(Palette.paper).navigationTitle("Rules")
  }
}

private struct RuleTile: View {
  @Environment(AppStore.self) private var store
  let rule: Rule
  var body: some View {
    let state = store.rules[rule.id]
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(rule.cefr.rawValue).font(.caption.weight(.medium)).foregroundStyle(Palette.secondary)
        Spacer()
        if state?.unlocked != true {
          Image(systemName: "lock").font(.caption).foregroundStyle(Palette.secondary)
        } else if state?.mastered == true {
          Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(Palette.success)
        } else if state?.lastSeen != nil && (state?.dueDate ?? .distantFuture) < Date.now {
          Label("Due", systemImage: "circle.fill").font(.caption2).foregroundStyle(Palette.amber)
        }
      }
      Text(rule.displayName).font(.subheadline.weight(.semibold)).frame(
        maxWidth: .infinity, minHeight: 48, alignment: .topLeading
      ).fixedSize(horizontal: false, vertical: true)
      MasterySegments(filled: state?.segments ?? 0)
    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(
      Palette.surface, in: RoundedRectangle(cornerRadius: 18)
    )
    .accessibilityElement(children: .combine)
  }
}

struct RuleDetailView: View {
  @Environment(AppStore.self) private var store
  let rule: Rule
  var body: some View {
    let state = store.rules[rule.id]
    let attempts = store.history.filter { $0.ruleIds.contains(rule.id) }
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          BandBadge(band: rule.cefr)
          Text(rule.category).font(.subheadline).foregroundStyle(Palette.secondary)
        }
        Text(rule.displayName).font(.system(.largeTitle, design: .serif, weight: .medium))
        VStack(alignment: .leading, spacing: 16) {
          Text(rule.explainer["en"] ?? "").font(.body).lineSpacing(5)
          if let table = rule.table {
            ForEach(Array(table.enumerated()), id: \.offset) { _, row in
              HStack {
                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                  Text(cell).font(.caption).frame(maxWidth: .infinity)
                }
              }
            }
          }
        }.surfaceCard()
        VStack(alignment: .leading, spacing: 12) {
          MasterySegments(filled: state?.segments ?? 0)
          HStack {
            Text(
              state?.mastered == true
                ? "Mastered"
                : state?.lastSeen == nil
                  ? "Not practiced yet" : "\(state?.hintLevel.name ?? "Guided") practice"
            ).font(.subheadline.weight(.medium))
            Spacer()
            if let state, state.attempts > 0 {
              Text("\(Int(Double(state.firstTryCorrect)/Double(state.attempts)*100))% first try")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            }
          }
          if !attempts.isEmpty {
            Chart(Array(attempts.suffix(20).enumerated()), id: \.offset) { index, attempt in
              LineMark(
                x: .value("Attempt", index + 1),
                y: .value("First try", attempt.failedRuleIds.contains(rule.id) ? 0 : 1)
              ).foregroundStyle(Palette.accent)
              PointMark(
                x: .value("Attempt", index + 1),
                y: .value("First try", attempt.failedRuleIds.contains(rule.id) ? 0 : 1)
              ).foregroundStyle(Palette.accent)
            }.chartYScale(domain: 0...1).chartYAxis(.hidden).chartXAxis(.hidden).frame(height: 75)
              .accessibilityLabel("Recent first-attempt results for this rule")
          }
        }.surfaceCard()
        let examples = completedExamples()
        if !examples.isEmpty {
          Text("Connections you’ve made").font(.title3.weight(.semibold))
          ForEach(Array(examples.enumerated()), id: \.offset) { _, pair in
            VStack(alignment: .leading, spacing: 12) {
              Text(pair.0).font(.system(.body, design: .serif)).foregroundStyle(Palette.secondary)
              Image(systemName: "arrow.down").foregroundStyle(Palette.accent)
              Text(pair.1).font(.system(.title3, design: .serif))
            }.frame(maxWidth: .infinity, alignment: .leading).surfaceCard()
          }
        }
        if state?.unlocked != true {
          VStack(alignment: .leading, spacing: 8) {
            Label("Build the foundation first", systemImage: "lock").font(.headline)
            ForEach(rule.prerequisites, id: \.self) { id in
              Text(store.pack.rules.first { $0.id == id }?.displayName ?? id).font(.subheadline)
                .foregroundStyle(Palette.secondary)
            }
          }.surfaceCard()
        }
        PrimaryButton("Practice this rule", symbol: "arrow.right", enabled: state?.unlocked == true)
        { store.practice(rule: rule) }
      }.padding(24).readingWidth()
    }.background(Palette.paper).navigationBarTitleDisplayMode(.inline)
  }
  private func completedExamples() -> [(String, String)] {
    var pairs: [(String, String)] = []
    for record in store.completions {
      guard let chain = record.chain ?? store.pack.chains.first(where: { $0.id == record.chainId })
      else { continue }
      for (i, step) in chain.steps.enumerated() where step.ruleIDs.contains(rule.id) {
        let before = i == 0 ? chain.base : chain.steps[i - 1].snapshot
        let a = Sentence.text(before.tokens, terminal: before.terminal ?? chain.terminal)
        let b = Sentence.text(step.tokens, terminal: step.terminal ?? chain.terminal)
        if !pairs.contains(where: { $0.1 == b }) { pairs.append((a, b)) }
        if pairs.count == 3 { return pairs }
      }
    }
    return pairs
  }
}
