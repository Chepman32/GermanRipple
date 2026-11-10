import RippleEngine
import SwiftUI

enum Palette {
  static let ink = Color.primary
  static let paper = Color(uiColor: .systemGroupedBackground)
  static let surface = Color(uiColor: .secondarySystemGroupedBackground)
  static let accent = Color("AccentColor")
  static let amber = Color("Attention")
  static let success = Color("Success")
  static let wrong = Color("Error")
  static let subtle = Color(uiColor: .tertiarySystemFill)
  static let secondary = Color("SecondaryText")
}

enum Theme {
  static func symbol(_ name: String) -> String {
    switch name {
    case "cafe": "cup.and.saucer"
    case "home": "house"
    case "travel": "tram"
    case "work": "briefcase"
    case "shopping": "bag"
    case "health": "leaf"
    case "weather": "cloud.sun"
    case "family": "person.2"
    case "city": "building.2"
    case "food": "carrot"
    case "free-time": "book"
    default: "calendar"
    }
  }
  static func label(_ name: String) -> String {
    name == "free-time" ? "Free time" : name.capitalized
  }
}

struct RippleMark: View {
  var size: CGFloat = 76
  var body: some View {
    ZStack {
      ForEach(0..<4) { i in
        Circle().stroke(Palette.accent.opacity(0.16 + Double(3 - i) * 0.08), lineWidth: 1.5)
          .frame(width: size * CGFloat(i + 1) / 4, height: size * CGFloat(i + 1) / 4)
          .offset(x: CGFloat(i) * 2, y: CGFloat(i) * (-1.5))
      }
      Circle().fill(Palette.accent).frame(width: 7, height: 7)
    }.frame(width: size + 12, height: size + 12).accessibilityHidden(true)
  }
}

struct PrimaryButton: View {
  let title: String
  var symbol: String? = nil
  var enabled = true
  var action: () -> Void
  init(_ title: String, symbol: String? = nil, enabled: Bool = true, action: @escaping () -> Void) {
    self.title = title
    self.symbol = symbol
    self.enabled = enabled
    self.action = action
  }
  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Text(title).font(.headline)
        if let symbol { Image(systemName: symbol).font(.body.weight(.semibold)) }
      }.frame(maxWidth: .infinity).padding(.vertical, 17).padding(.horizontal, 12)
    }.buttonStyle(.plain).foregroundStyle(Color("OnAccent")).background(
      enabled ? Palette.accent : Color.secondary, in: RoundedRectangle(cornerRadius: 18)
    )
    .disabled(!enabled).opacity(enabled ? 1 : 0.6).frame(minHeight: 52)
  }
}

struct RuleChip: View {
  let label: String
  var body: some View {
    Text(label).font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
      .padding(.horizontal, 10).padding(.vertical, 6).background(
        Palette.accent.opacity(0.08), in: Capsule())
  }
}

struct BandBadge: View {
  var band: CEFR
  var body: some View {
    Text(band.rawValue).font(.caption.weight(.semibold)).monospaced().padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(Palette.subtle, in: RoundedRectangle(cornerRadius: 7)).accessibilityLabel(
        "Level \(band.rawValue)")
  }
}

struct MasterySegments: View {
  var filled: Int
  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<5) { i in
        Capsule().fill(i < filled ? Palette.accent : Palette.subtle).frame(height: 5)
      }
    }
    .accessibilityLabel("Mastery: \(filled) of 5")
  }
}

struct FlowLayout: Layout {
  var spacing: CGFloat = 4
  var lineSpacing: CGFloat = 8
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(subviews, width: proposal.width ?? 340).size
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = arrange(subviews, width: bounds.width)
    for (i, position) in result.positions.enumerated() {
      subviews[i].place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: ProposedViewSize(width: result.sizes[i].width, height: result.sizes[i].height))
    }
  }
  private func arrange(_ subviews: Subviews, width: CGFloat) -> (
    positions: [CGPoint], sizes: [CGSize], size: CGSize
  ) {
    var positions: [CGPoint] = []
    var sizes: [CGSize] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxWidth: CGFloat = 0
    for view in subviews {
      let natural = view.sizeThatFits(.unspecified)
      let size = view.sizeThatFits(ProposedViewSize(width: min(natural.width, width), height: nil))
      if x > 0 && x + size.width > width {
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      sizes.append(size)
      maxWidth = max(maxWidth, x + size.width)
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    return (positions, sizes, CGSize(width: width, height: y + lineHeight))
  }
}

struct EmptyState: View {
  var symbol: String
  var title: String
  var message: String
  var actionTitle: String? = nil
  var action: () -> Void = {}
  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: symbol).font(.system(size: 44, weight: .light)).foregroundStyle(
        Palette.accent
      ).padding(.bottom, 8)
      Text(title).font(.title2.weight(.semibold))
      Text(message).font(.body).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
      if let actionTitle {
        Button(actionTitle, action: action).buttonStyle(.borderedProminent).padding(.top, 8)
      }
    }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

extension View {
  func surfaceCard() -> some View {
    padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
  }
  func readingWidth() -> some View { frame(maxWidth: 680).frame(maxWidth: .infinity) }
}
