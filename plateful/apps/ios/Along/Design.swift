import SwiftUI

private struct AlongForcedReducedMotion: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var alongForcedReducedMotion: Bool {
        get { self[AlongForcedReducedMotion.self] }
        set { self[AlongForcedReducedMotion.self] = newValue }
    }
    var alongReducedMotion: Bool { accessibilityReduceMotion || alongForcedReducedMotion }
}

enum Theme {
    static let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.09, blue: 0.13, alpha: 1) : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1) })
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let plum = Color(red: 0.24, green: 0.19, blue: 0.30)
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.79, green: 0.72, blue: 0.91, alpha: 1) : UIColor(red: 0.24, green: 0.19, blue: 0.30, alpha: 1) })
    static let sage = Color(red: 0.79, green: 0.84, blue: 0.74)
    static let gold = Color(red: 0.95, green: 0.75, blue: 0.41)
    static let peach = Color(red: 0.85, green: 0.58, blue: 0.50)
    static let lilac = Color(red: 0.88, green: 0.84, blue: 0.93)
    static let ink = Color(red: 0.23, green: 0.20, blue: 0.28)
    static let secondaryInk = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.73, green: 0.70, blue: 0.77, alpha: 1) : UIColor(red: 0.43, green: 0.40, blue: 0.46, alpha: 1) })
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
        Text(store.journal.hasSampleData ? "SAMPLE JOURNEY" : store.journal.isDesignPreview == true ? "DESIGN PREVIEW" : "LOCAL PROTOTYPE")
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

// Original rendered artwork. Asset prompts and provenance are in docs/pip-art-direction.md.
enum PipPose: String {
    case welcome = "PipWelcome"
    case journal = "PipJournal"
    case celebrate = "PipCelebrate"
}
struct PipArtwork: View {
    var pose: PipPose = .welcome
    var accessory: Accessory = .leaf
    private var asset: String {
        switch accessory {
        case .leaf: return pose.rawValue
        case .scarf: return "PipScarf"
        case .flower: return "PipFlower"
        }
    }
    var body: some View {
        Image(asset).resizable().scaledToFit().accessibilityHidden(true)
    }
}
struct PipView: View {
    var accessory: Accessory = .leaf
    var wave = false
    var body: some View { PipArtwork(pose: .welcome, accessory: accessory).rotationEffect(.degrees(wave ? -2 : 0)) }
}

struct MeadowView: View {
    var accessory: Accessory = .leaf
    var compact = false
    @Environment(\.alongReducedMotion) private var reduceMotion
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
