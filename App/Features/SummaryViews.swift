import RippleEngine
import SwiftUI
import UIKit

struct ChainSummaryView: View {
  @Environment(AppStore.self) private var store
  @State private var shareImage: UIImage?
  @State private var sharing = false
  var body: some View {
    if let session = store.session {
      let chain = session.current
      let results = session.player.results
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            HStack {
              Text("A sentence, built by you.").font(.subheadline).foregroundStyle(Palette.secondary)
              Spacer()
              RippleMark(size: 42)
            }.id("summary.top")
            Text(session.mode == .peel ? "Back to the beginning." : "Look what you\ncan say now.")
              .font(.system(.largeTitle, design: .serif, weight: .medium))
              .accessibilityIdentifier("summary.heading")
            VStack(alignment: .leading, spacing: 14) {
              Text("You started with").font(.caption.weight(.medium)).foregroundStyle(
                Palette.secondary)
              Text(Sentence.text(chain.base.tokens, terminal: chain.base.terminal ?? chain.terminal))
                .font(.system(.title3, design: .serif)).foregroundStyle(Palette.secondary)
              Image(systemName: "arrow.down").font(.title3).foregroundStyle(Palette.accent).padding(
                .vertical, 8)
              Text(
                Sentence.text(chain.final.tokens, terminal: chain.final.terminal ?? chain.terminal)
              ).font(.system(.title, design: .serif, weight: .medium)).lineSpacing(5).fixedSize(
                horizontal: false, vertical: true)
              Text(chain.final.gloss["en"] ?? "").foregroundStyle(Palette.secondary).lineSpacing(4)
              Button("Hear it", systemImage: "speaker.wave.2") {
                store.audio.speak(
                  tokens: chain.final.tokens, terminal: chain.final.terminal ?? chain.terminal,
                  settings: store.settings)
              }.buttonStyle(.bordered).frame(minHeight: 44)
            }.frame(maxWidth: .infinity, alignment: .leading).surfaceCard()
            HStack(spacing: 0) {
              stat(
                "\(Sentence.wordCount(chain.base.tokens)) → \(Sentence.wordCount(chain.final.tokens))",
                "words")
              Divider().frame(height: 46)
              stat(
                "\(results.filter(\.firstTryCorrect).count) of \(results.count)", "steps first try")
            }.surfaceCard()
            FlowLayout(spacing: 8, lineSpacing: 8) {
              ForEach(store.pack.rules.filter { chain.ruleIDs.contains($0.id) }) { rule in
                let was = session.initialStrengths[rule.id] ?? 0
                let now = store.rules[rule.id]?.strength ?? 0
                RuleChip(label: (now > was ? "↑ " : now < was ? "↓ " : "") + rule.displayName)
              }
            }
            PrimaryButton(
              session.mode == .demo
                ? "Continue setup"
                : session.mode == .placement && session.position + 1 < session.queue.count
                  ? "Next level check"
                  : session.position + 1 < session.queue.count
                    ? "Next chain"
                    : session.mode == .placement ? "See my starting level" : "Finish this session",
              symbol: "arrow.right"
            ) { store.nextChain() }.accessibilityIdentifier("summary.next")
            if session.mode == .forward || session.mode == .peel {
              HStack {
                Button("Done for now") { store.finishSession() }.frame(minHeight: 44)
                Spacer()
                Button("Share", systemImage: "square.and.arrow.up") { renderShare(chain) }.frame(
                  minHeight: 44)
              }
              if session.mode == .forward && (store.canPeel || store.settings.completedSessions > 0) {
                Button(
                  store.canPeel ? "Peel it back" : "Peel it back · Pro",
                  systemImage: "arrow.uturn.backward"
                ) { store.peel(chain) }.frame(minHeight: 44)
              }
            }
          }.padding(24).readingWidth()
        }.background(Palette.paper).sheet(isPresented: $sharing) {
          if let shareImage { ShareSheet(items: [shareImage]) }
        }
        .id("chain-summary-\(chain.id)")
        .onAppear { proxy.scrollTo("summary.top", anchor: .top) }
      }
    }
  }
  private func stat(_ value: String, _ caption: String) -> some View {
    VStack(spacing: 6) {
      Text(value).font(.system(.title2, design: .serif, weight: .medium))
      Text(caption).font(.caption).foregroundStyle(Palette.secondary)
    }.frame(maxWidth: .infinity)
  }
  @MainActor private func renderShare(_ chain: Chain) {
    let renderer = ImageRenderer(
      content: SentenceShareCard(chain: chain).environment(\.colorScheme, .light))
    renderer.scale = 2
    guard let image = renderer.uiImage else {
      store.errorMessage = "The share image couldn’t be created. Please try again."
      return
    }
    shareImage = image
    sharing = true
  }
}

struct SessionSummaryView: View {
  @Environment(AppStore.self) private var store
  @State private var askingReminder = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        RippleMark(size: 90).padding(.vertical, 16)
        Text("Small steps.\nStronger connections.").font(
          .system(.largeTitle, design: .serif, weight: .medium))
        Text(
          "You completed \(store.session?.committed.count ?? 0) chains. Every connection gets a little easier with practice."
        ).foregroundStyle(Palette.secondary).lineSpacing(5)
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text("\(store.streak) day\(store.streak==1 ? "" : "s")").font(.title2.weight(.medium))
            Text("Your practice streak").font(.caption).foregroundStyle(Palette.secondary)
          }
          Spacer()
          Image(systemName: "flame").font(.largeTitle.weight(.light)).foregroundStyle(
            Palette.accent)
        }.surfaceCard()
        if let session = store.session {
          let changed = store.pack.rules.filter { rule in
            let was = session.initialStrengths[rule.id] ?? 0
            return (store.rules[rule.id]?.strength ?? 0) > was
          }
          if !changed.isEmpty {
            Text("Connections strengthened").font(.title3.weight(.semibold))
            ForEach(changed) { rule in
              HStack {
                VStack(alignment: .leading, spacing: 8) {
                  Text(rule.displayName).font(.subheadline.weight(.medium))
                  MasterySegments(filled: store.rules[rule.id]?.segments ?? 0)
                }
                Spacer(minLength: 16)
                Image(systemName: "arrow.up.right").foregroundStyle(Palette.success)
              }.surfaceCard()
            }
          }
        }
        PrimaryButton("Done for today", symbol: "checkmark") { store.finishSession() }
          .accessibilityIdentifier("session.done")
        Button("Keep practicing") {
          store.finishSession()
          store.startToday()
        }.frame(maxWidth: .infinity, minHeight: 44)
        if !store.settings.reminderAsked {
          Button("Choose a gentle daily reminder", systemImage: "bell") { askingReminder = true }
            .frame(minHeight: 44)
          Text("One reminder a day, at a time you choose.").font(.caption).foregroundStyle(
            Palette.secondary)
        }
      }.padding(24).readingWidth()
    }.background(Palette.paper).sheet(
      isPresented: $askingReminder, onDismiss: { store.settings.reminderAsked = true }
    ) { NavigationStack { ReminderSettingsView() } }
  }
}

private struct SentenceShareCard: View {
  let chain: Chain
  var body: some View {
    VStack(alignment: .leading, spacing: 30) {
      HStack {
        Text("Ripple").font(.system(size: 32, weight: .semibold, design: .serif))
        Spacer()
        RippleMark(size: 58)
      }
      Text(Sentence.text(chain.base.tokens, terminal: chain.base.terminal ?? chain.terminal)).font(
        .system(size: 26, design: .serif)
      ).foregroundStyle(Palette.secondary)
      Image(systemName: "arrow.down").font(.title2).foregroundStyle(Palette.accent)
      Text(Sentence.text(chain.final.tokens, terminal: chain.final.terminal ?? chain.terminal))
        .font(.system(size: 34, weight: .medium, design: .serif)).lineSpacing(8)
      Text(chain.final.gloss["en"] ?? "").font(.system(size: 20)).foregroundStyle(Palette.secondary)
      Divider()
      Text(
        "\(Sentence.wordCount(chain.base.tokens)) → \(Sentence.wordCount(chain.final.tokens)) words. Built, one change at a time."
      ).font(.system(size: 17)).foregroundStyle(Palette.secondary)
    }.padding(48).frame(width: 660).background(Color(uiColor: .systemGroupedBackground))
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
