import SwiftUI

enum Theme {
    static let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.09, blue: 0.13, alpha: 1) : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1) })
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let plum = Color(red: 0.30, green: 0.23, blue: 0.40)
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.79, green: 0.72, blue: 0.91, alpha: 1) : UIColor(red: 0.30, green: 0.23, blue: 0.40, alpha: 1) })
    static let sage = Color(red: 0.79, green: 0.84, blue: 0.74)
    static let gold = Color(red: 0.95, green: 0.75, blue: 0.41)
    static let peach = Color(red: 0.85, green: 0.58, blue: 0.50)
    static let lilac = Color(red: 0.88, green: 0.84, blue: 0.93)
    static let ink = Color(red: 0.23, green: 0.20, blue: 0.28)
    static let line = Color.primary.opacity(0.07)
}
private struct AlongTitle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    init(_ size: CGFloat) { _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle) }
    func body(content: Content) -> some View { content.font(.system(size: size, weight: .medium, design: .serif)) }
}
extension View {
    func alongTitle(_ size: CGFloat = 34) -> some View { modifier(AlongTitle(size)) }
}
struct PrimaryButton: View {
    var title: String
    var symbol = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) { Text(title).font(.headline); Spacer(minLength: 8); Image(systemName: symbol).font(.headline) }
                .padding(.horizontal, 22).frame(minHeight: 56).foregroundStyle(.white)
                .background(Theme.plum, in: RoundedRectangle(cornerRadius: 19))
        }.buttonStyle(.plain)
    }
}
struct Pill: View {
    var text: String
    var symbol: String?
    var body: some View {
        HStack(spacing: 5) { if let symbol { Image(systemName: symbol) }; Text(text) }
            .font(.caption.weight(.medium)).padding(.horizontal, 11).padding(.vertical, 7)
            .background(.primary.opacity(0.055), in: Capsule())
    }
}
struct DemoBadge: View {
    @Environment(JournalStore.self) private var store
    var body: some View {
        Text(store.journal.hasSampleData ? "SAMPLE JOURNEY" : "LOCAL PROTOTYPE")
            .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.1)
            .padding(.horizontal, 9).padding(.vertical, 6).foregroundStyle(Theme.accent)
            .background(Theme.lilac.opacity(0.35), in: Capsule())
    }
}
struct SectionLabel: View {
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title3.weight(.semibold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct CardModifier: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content.padding(padding).background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.line, lineWidth: 1))
    }
}
extension View {
    func card(padding: CGFloat = 20) -> some View { modifier(CardModifier(padding: padding)) }
    func pageBackground() -> some View { background(Theme.paper) }
}
struct QuietEmpty: View {
    var symbol: String
    var title: String
    var detail: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 28)).foregroundStyle(Theme.accent).frame(width: 68, height: 68).background(Theme.lilac.opacity(0.4), in: Circle())
            Text(title).font(.title3.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(10).frame(maxWidth: .infinity).card()
    }
}

// An original code-native character. No competitor art or external image assets.
struct PipView: View {
    var accessory: Accessory = .leaf
    var wave = false
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Ellipse().fill(Theme.ink.opacity(0.10)).frame(width: s * 0.62, height: s * 0.075).offset(y: s * 0.38)
                RoundedRectangle(cornerRadius: s * 0.1).fill(Color(red: 0.52, green: 0.58, blue: 0.40)).frame(width: s * 0.31, height: s * 0.38).rotationEffect(.degrees(-12)).offset(x: s * 0.25, y: s * 0.10)
                Ellipse().fill(Color(red: 0.83, green: 0.55, blue: 0.42)).frame(width: s * 0.14, height: s * 0.27).rotationEffect(.degrees(wave ? -50 : -25)).offset(x: -s * 0.30, y: s * (wave ? -0.03 : 0.12))
                Ellipse().fill(Color(red: 0.83, green: 0.55, blue: 0.42)).frame(width: s * 0.13, height: s * 0.26).rotationEffect(.degrees(25)).offset(x: s * 0.30, y: s * 0.12)
                Capsule().fill(Color(red: 0.82, green: 0.53, blue: 0.40)).frame(width: s * 0.19, height: s * 0.14).offset(x: -s * 0.16, y: s * 0.32)
                Capsule().fill(Color(red: 0.82, green: 0.53, blue: 0.40)).frame(width: s * 0.19, height: s * 0.14).offset(x: s * 0.16, y: s * 0.32)
                Ellipse().fill(Color(red: 0.91, green: 0.68, blue: 0.53)).frame(width: s * 0.62, height: s * 0.70).offset(y: s * 0.02)
                Ellipse().fill(Color(red: 0.98, green: 0.83, blue: 0.68)).frame(width: s * 0.40, height: s * 0.36).offset(y: s * 0.16)
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Circle().fill(Color(red: 0.91, green: 0.68, blue: 0.53)).frame(width: s * 0.19).overlay(Circle().fill(Theme.peach.opacity(0.7)).padding(s * 0.04)).offset(x: side * s * 0.22, y: -s * 0.26)
                }
                Ellipse().fill(Color(red: 0.94, green: 0.73, blue: 0.58)).frame(width: s * 0.65, height: s * 0.49).offset(y: -s * 0.09)
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Capsule().fill(Theme.ink).frame(width: s * 0.025, height: s * 0.041).offset(x: side * s * 0.105, y: -s * 0.105)
                    Ellipse().fill(Theme.peach.opacity(0.8)).frame(width: s * 0.08, height: s * 0.045).offset(x: side * s * 0.18, y: -s * 0.045)
                }
                Ellipse().fill(Theme.ink).frame(width: s * 0.045, height: s * 0.033).offset(y: -s * 0.045)
                Path { path in path.move(to: CGPoint(x: s * 0.46, y: s * 0.49)); path.addQuadCurve(to: CGPoint(x: s * 0.54, y: s * 0.49), control: CGPoint(x: s * 0.50, y: s * 0.53)) }.stroke(Theme.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: s, height: s)
                if accessory == .leaf {
                    Image(systemName: "leaf.fill").font(.system(size: s * 0.20)).rotationEffect(.degrees(-35)).foregroundStyle(Color(red: 0.39, green: 0.49, blue: 0.32)).offset(x: s * 0.04, y: -s * 0.35)
                } else if accessory == .scarf {
                    Capsule().fill(Theme.plum).frame(width: s * 0.45, height: s * 0.10).offset(y: s * 0.10)
                    RoundedRectangle(cornerRadius: 5).fill(Theme.plum).frame(width: s * 0.09, height: s * 0.22).rotationEffect(.degrees(15)).offset(x: s * 0.12, y: s * 0.20)
                } else {
                    Image(systemName: "sun.max.fill").font(.system(size: s * 0.19)).foregroundStyle(Theme.gold).offset(x: s * 0.16, y: -s * 0.30)
                }
            }.frame(width: geo.size.width, height: geo.size.height)
        }.accessibilityHidden(true)
    }
}

struct MeadowView: View {
    var accessory: Accessory = .leaf
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.93, green: 0.91, blue: 0.88), Color(red: 0.88, green: 0.90, blue: 0.84)], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 0.98, green: 0.89, blue: 0.66)).frame(width: 60, height: 60).offset(x: geo.size.width * 0.30, y: -geo.size.height * 0.26)
                Ellipse().fill(Color(red: 0.81, green: 0.85, blue: 0.74)).frame(width: geo.size.width * 1.5, height: geo.size.height * 0.75).offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.48)
                Ellipse().fill(Color(red: 0.73, green: 0.79, blue: 0.64)).frame(width: geo.size.width * 1.3, height: geo.size.height * 0.55).offset(x: geo.size.width * 0.3, y: geo.size.height * 0.49)
                ForEach(0..<5) { index in
                    Image(systemName: index.isMultiple(of: 2) ? "leaf.fill" : "sparkle")
                        .font(.system(size: index.isMultiple(of: 2) ? 19 : 13)).foregroundStyle(index.isMultiple(of: 2) ? Color(red: 0.49, green: 0.60, blue: 0.39) : .white.opacity(0.9))
                        .rotationEffect(.degrees(Double(index * 42)))
                        .offset(x: CGFloat([-0.36, 0.29, 0.36, -0.27, -0.41][index]) * geo.size.width, y: CGFloat([0.22, 0.05, 0.32, -0.23, -0.01][index]) * geo.size.height)
                }
                PipView(accessory: accessory, wave: floating).frame(width: geo.size.height * 0.84, height: geo.size.height * 0.84).offset(y: floating && !reduceMotion ? 2 : 5)
            }.frame(width: geo.size.width, height: geo.size.height).clipped()
        }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { floating = true } } }
        .accessibilityHidden(true)
    }
}
