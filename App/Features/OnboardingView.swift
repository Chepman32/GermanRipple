import RippleEngine
import SwiftUI

struct OnboardingView: View {
  @Environment(AppStore.self) private var store
  @State private var goal = 3
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        HStack {
          Text("Ripple").font(.system(.title2, design: .serif, weight: .semibold))
          Spacer()
          Text("German, one connection at a time").font(.caption).foregroundStyle(Palette.secondary)
        }
        RippleMark(size: 120).frame(maxWidth: .infinity).padding(.vertical, 24)
        switch store.onboardingPage {
        case 0:
          Text("Change one word.\nSee what follows.").font(
            .system(.largeTitle, design: .serif, weight: .medium))
          Text(
            "Build German sentences by changing one thing at a time. Follow the ripple, and make the grammar yours."
          ).font(.title3).foregroundStyle(Palette.secondary).lineSpacing(5)
          VStack(spacing: 20) {
            languageRow("I speak", "English", symbol: "text.bubble")
            Divider()
            languageRow("I’m learning", "German", symbol: "globe.europe.africa")
          }.surfaceCard()
          Text("More languages will follow. Your first lessons are ready offline.").font(.caption)
            .foregroundStyle(Palette.secondary)
          PrimaryButton("Try a ripple", symbol: "arrow.right") {
            store.onboardingPage = 1
            store.backend.event("onboarding_step", ["step": 1])
            store.startDemo()
          }.accessibilityIdentifier("onboarding.try")
          Button("Skip the demo") { store.onboardingPage = 2 }.frame(
            maxWidth: .infinity, minHeight: 44
          ).accessibilityIdentifier("onboarding.skip")
        case 1:
          Text("A sentence you\ncan build yourself.").font(
            .system(.largeTitle, design: .serif, weight: .medium))
          Text("Try three small changes. No score, no timer — just a first connection.")
            .foregroundStyle(Palette.secondary)
          PrimaryButton("Continue the demo", symbol: "arrow.right") {
            if store.session?.mode == .demo { store.showPractice = true } else { store.startDemo() }
          }
          Button("Skip the demo") {
            store.finishSession()
            store.onboardingPage = 2
          }.frame(maxWidth: .infinity, minHeight: 44)
        case 2:
          Text("Already know\nsome German?").font(
            .system(.largeTitle, design: .serif, weight: .medium))
          Text(
            "A few quick chains help find your starting point. Or start with the foundations and build from there."
          ).font(.title3).foregroundStyle(Palette.secondary).lineSpacing(5)
          Label("About 2 minutes · A1 to B1", systemImage: "clock").font(.subheadline)
            .foregroundStyle(Palette.secondary)
          PrimaryButton("Find my level", symbol: "arrow.right") { store.startPlacement() }
            .accessibilityIdentifier("onboarding.placement")
          Button("Start from the beginning") {
            store.settings.band = .a1
            store.onboardingPage = 3
          }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("onboarding.beginner")
        default:
          Text("A little,\nevery day.").font(.system(.largeTitle, design: .serif, weight: .medium))
          Text("Choose a daily goal. You can change it anytime.").font(.title3).foregroundStyle(
            Palette.secondary)
          ForEach([3, 6, 9], id: \.self) { count in
            Button {
              goal = count
              Feedback.selection(store.settings)
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 6) {
                  Text("\(count) chains").font(.headline)
                  Text("About \(count/3*5) minutes").font(.subheadline).foregroundStyle(
                    Palette.secondary)
                }
                Spacer()
                Image(systemName: goal == count ? "checkmark.circle.fill" : "circle").font(.title2)
                  .foregroundStyle(goal == count ? Palette.accent : Color.secondary)
              }.surfaceCard()
            }.buttonStyle(.plain).accessibilityLabel(
              "\(count) chains, about \(count/3*5) minutes\(goal==count ? ", selected":"")")
          }
          Text("Free includes 3 chains each day. Pro adds unlimited practice.").font(.caption)
            .foregroundStyle(Palette.secondary)
          PrimaryButton("Start learning", symbol: "arrow.right") {
            store.settings.dailyGoal = goal
            store.settings.onboardingComplete = true
            store.refreshToday()
            store.backend.event("onboarding_step", ["step": 4])
          }.accessibilityIdentifier("onboarding.finish")
        }
      }.padding(28).readingWidth()
    }.background(Palette.paper)
  }
  private func languageRow(_ label: String, _ value: String, symbol: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: symbol).font(.title3).foregroundStyle(Palette.accent).frame(width: 30)
      Text(label).foregroundStyle(Palette.secondary)
      Spacer()
      Text(value).fontWeight(.semibold)
    }
  }
}
