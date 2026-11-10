import RippleEngine
import SwiftUI

struct TodayView: View {
  @Environment(AppStore.self) private var store
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Label("German · \(store.settings.band.rawValue)", systemImage: "globe.europe.africa")
            .font(.subheadline.weight(.medium)).foregroundStyle(Palette.secondary)
          Spacer()
          Label("\(store.streak)", systemImage: "flame").font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.accent)
            .accessibilityLabel("\(store.streak) day streak")
        }
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 10) {
            Text(
              store.todayCount >= store.settings.dailyGoal
                ? "Look how far\nyou’ve come." : "Little changes.\nLonger sentences."
            )
            .font(.system(.largeTitle, design: .serif, weight: .medium)).fixedSize(
              horizontal: false, vertical: true)
            Text("Grammar you can feel.").foregroundStyle(Palette.secondary)
          }
          Spacer(minLength: 0)
          RippleMark(size: 78)
        }.padding(.vertical, 8)
        if !store.backend.maintenanceMessage.isEmpty {
          Label(store.backend.maintenanceMessage, systemImage: "info.circle").font(.subheadline)
            .surfaceCard()
        }
        if store.updateRequiresApp {
          Label(
            "A newer Ripple version is available. Your current lessons still work offline.",
            systemImage: "arrow.down.app"
          ).font(.subheadline).surfaceCard()
        }
        dailyProgress
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text("Your next ripples").font(.title3.weight(.semibold))
            Spacer()
            Text("About 5 min").font(.subheadline).foregroundStyle(Palette.secondary)
          }
          ForEach(Array(store.todayChains.enumerated()), id: \.element.id) { index, chain in
            ChainRow(chain: chain, number: index + 1)
          }
        }
        if store.longestSentence > 0 {
          HStack(spacing: 14) {
            Image(systemName: "text.alignleft").font(.title2).foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 4) {
              Text("\(store.longestSentence) words, built by you").font(
                .subheadline.weight(.semibold))
              Text("Your longest sentence so far.").font(.caption).foregroundStyle(
                Palette.secondary)
            }
          }.frame(maxWidth: .infinity, alignment: .leading).surfaceCard()
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("One sentence. A ripple of possibilities.").font(.subheadline.weight(.semibold))
            Text("Change a word, discover what follows, and build something you can actually say.")
              .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(3)
          }.padding(.horizontal, 4).padding(.bottom, 8)
        }
      }.padding(24).readingWidth()
    }.background(Palette.paper).navigationTitle("Today")
      .safeAreaInset(edge: .bottom, spacing: 0) {
        PrimaryButton(
          store.hasResume
            ? "Continue your chain"
            : store.todayCount >= store.settings.dailyGoal
              ? "One more chain" : "Start today’s practice", symbol: "arrow.right"
        ) { store.startToday() }
        .accessibilityIdentifier("today.start").padding(.horizontal, 24).padding(.top, 12).padding(
          .bottom, 8
        ).readingWidth().background(Palette.paper)
      }
  }
  private var dailyProgress: some View {
    HStack(spacing: 18) {
      ZStack {
        Circle().stroke(Palette.subtle, lineWidth: 5)
        Circle().trim(
          from: 0, to: min(1, Double(store.todayCount) / Double(store.settings.dailyGoal))
        )
        .stroke(Palette.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(
          .degrees(-90))
        Image(systemName: store.todayCount >= store.settings.dailyGoal ? "checkmark" : "sparkle")
          .font(.title3).foregroundStyle(Palette.accent)
      }.frame(width: 50, height: 50).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(
          store.todayCount >= store.settings.dailyGoal
            ? "Daily goal, done" : "A little practice goes a long way"
        ).font(.subheadline.weight(.semibold))
        Text("\(store.todayCount) of \(store.settings.dailyGoal) chains today").font(.subheadline)
          .foregroundStyle(Palette.secondary)
      }
      Spacer(minLength: 0)
    }.surfaceCard().accessibilityElement(children: .combine)
  }
}

struct ChainRow: View {
  @Environment(AppStore.self) private var store
  let chain: Chain
  var number: Int
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: Theme.symbol(chain.theme)).font(.title2.weight(.light)).foregroundStyle(
        Palette.accent
      )
      .frame(width: 44, height: 48).background(
        Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)
      ).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text(chain.name).font(.headline)
          Spacer(minLength: 4)
          BandBadge(band: chain.cefr)
        }
        Text(Sentence.text(chain.base.tokens, terminal: chain.base.terminal ?? chain.terminal))
          .font(.system(.body, design: .serif)).foregroundStyle(Palette.secondary)
        HStack(spacing: 8) {
          Text("\(chain.steps.count) changes").font(.caption).foregroundStyle(Palette.secondary)
          Text("·").foregroundStyle(.tertiary)
          Text(Theme.label(chain.theme)).font(.caption).foregroundStyle(Palette.secondary)
        }
      }
    }.surfaceCard().accessibilityElement(children: .combine)
  }
}
