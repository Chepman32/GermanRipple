import RippleEngine
import SwiftUI

struct GalleryView: View {
  @Environment(AppStore.self) private var store
  @State private var query = ""
  private var records: [ChainRecord] {
    store.completions.filter { record in
      guard record.mode == "forward" else { return false }
      guard let chain = record.chain ?? store.pack.chains.first(where: { $0.id == record.chainId })
      else { return false }
      return query.isEmpty || Sentence.text(chain.final.tokens).localizedStandardContains(query)
        || chain.name.localizedStandardContains(query)
    }
  }
  var body: some View {
    Group {
      if store.completions.filter({ $0.mode == "forward" }).isEmpty {
        EmptyState(
          symbol: "rectangle.stack", title: "Your words belong here.",
          message:
            "Every sentence you build becomes part of your collection. Finish a chain to save your first one.",
          actionTitle: "Start a chain"
        ) {
          store.selectedTab = 0
          store.startToday()
        }
      } else if records.isEmpty {
        ContentUnavailableView.search(text: query)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 18) {
            Text("Sentences you can call your own.").font(.system(.title2, design: .serif)).padding(
              .bottom, 6)
            ForEach(records, id: \.key) { record in
              if let chain = record.chain
                ?? store.pack.chains.first(where: { $0.id == record.chainId })
              {
                NavigationLink {
                  SentenceDetailView(chain: chain, record: record)
                } label: {
                  VStack(alignment: .leading, spacing: 14) {
                    HStack {
                      Label(Theme.label(chain.theme), systemImage: Theme.symbol(chain.theme)).font(
                        .caption.weight(.medium))
                      Spacer()
                      Text(record.completedAt, style: .date).font(.caption).foregroundStyle(
                        Palette.secondary)
                    }
                    Text(
                      Sentence.text(
                        chain.final.tokens, terminal: chain.final.terminal ?? chain.terminal)
                    ).font(.system(.title3, design: .serif)).lineSpacing(5).multilineTextAlignment(
                      .leading)
                    HStack {
                      Text("\(Sentence.wordCount(chain.final.tokens)) words").font(.caption)
                        .foregroundStyle(Palette.secondary)
                      Spacer()
                      Image(systemName: "arrow.up.right").font(.caption)
                    }
                  }.frame(maxWidth: .infinity, alignment: .leading).surfaceCard()
                }.buttonStyle(.plain)
              }
            }
          }.padding(24).readingWidth()
        }
      }
    }.background(Palette.paper).navigationTitle("Gallery").searchable(
      text: $query, prompt: "Find a German word or sentence")
  }
}

struct SentenceDetailView: View {
  @Environment(AppStore.self) private var store
  let chain: Chain
  var record: ChainRecord?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          BandBadge(band: chain.cefr)
          Text(Theme.label(chain.theme)).font(.subheadline).foregroundStyle(Palette.secondary)
        }
        Text(Sentence.text(chain.final.tokens, terminal: chain.final.terminal ?? chain.terminal))
          .font(.system(.largeTitle, design: .serif, weight: .medium)).lineSpacing(5)
        Text(chain.final.gloss["en"] ?? "").foregroundStyle(Palette.secondary).lineSpacing(4)
        Button("Hear your sentence", systemImage: "speaker.wave.2") {
          store.audio.speak(
            tokens: chain.final.tokens, terminal: chain.final.terminal ?? chain.terminal,
            settings: store.settings)
        }.buttonStyle(.bordered).frame(minHeight: 44)
        Divider()
        Text("How you built it").font(.title3.weight(.semibold))
        layer(number: 0, label: "The beginning", snapshot: chain.base)
        ForEach(Array(chain.steps.enumerated()), id: \.offset) { i, step in
          layer(number: i + 1, label: step.card.label, snapshot: step.snapshot)
        }
        PrimaryButton("Peel the layers back", symbol: "arrow.uturn.backward") { store.peel(chain) }
        Text(
          store.canPeel
            ? "Start from the last sentence. Undo one change at a time."
            : "Peel is included with Ripple Pro."
        ).font(.caption).foregroundStyle(Palette.secondary)
      }.padding(24).readingWidth()
    }.background(Palette.paper).navigationTitle(chain.name).navigationBarTitleDisplayMode(.inline)
  }
  private func layer(number: Int, label: String, snapshot: Snapshot) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text("\(number)").font(.caption.monospaced()).foregroundStyle(Palette.accent).frame(
        width: 28, height: 28
      ).background(Palette.accent.opacity(0.08), in: Circle())
      VStack(alignment: .leading, spacing: 8) {
        Text(label).font(.caption).foregroundStyle(Palette.secondary)
        Text(Sentence.text(snapshot.tokens, terminal: snapshot.terminal ?? chain.terminal)).font(
          .system(.body, design: .serif)
        ).lineSpacing(3)
        Text(snapshot.gloss["en"] ?? "").font(.caption).foregroundStyle(Palette.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.padding(.vertical, 8)
  }
}
