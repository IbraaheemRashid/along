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
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.15, green: 0.13, blue: 0.18, alpha: 1) : UIColor(red: 1, green: 0.995, blue: 0.98, alpha: 1) })
    static let softAccent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.24, green: 0.20, blue: 0.29, alpha: 1) : UIColor(red: 0.93, green: 0.89, blue: 0.95, alpha: 1) })
    static let softApricot = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.29, green: 0.21, blue: 0.23, alpha: 1) : UIColor(red: 0.99, green: 0.91, blue: 0.85, alpha: 1) })
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
            HStack(spacing: 10) { Text(title).font(.system(.headline, design: .rounded)).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 8); Image(systemName: symbol).font(.headline) }
                .padding(.horizontal, 22).padding(.vertical, 16).frame(minHeight: 56).foregroundStyle(.white)
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
            .foregroundStyle(Theme.accent).background(Theme.softAccent, in: Capsule())
    }
}
struct DemoBadge: View {
    @Environment(JournalStore.self) private var store
    var body: some View {
        Text(store.journal.hasSampleData ? "SAMPLE JOURNEY" : store.journal.isDesignPreview == true ? "DESIGN PREVIEW" : "ON THIS DEVICE")
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
            Text(title).font(.system(.title3, design: .rounded, weight: .semibold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Theme.secondaryInk) }
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
            Text(title).font(.system(.title3, design: .rounded, weight: .semibold))
            Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryInk).multilineTextAlignment(.center)
        }.padding(10).frame(maxWidth: .infinity).card()
    }
}

struct AlongIcon: View {
    var symbol: String
    var apricot = false
    var body: some View {
        Image(systemName: symbol).font(.system(.title3, design: .rounded))
            .foregroundStyle(Theme.accent).frame(width: 44, height: 44)
            .background(apricot ? Theme.softApricot : Theme.softAccent, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

struct AlongField: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line))
    }
}
extension View {
    func alongField() -> some View { modifier(AlongField()) }
    func alongList() -> some View { scrollContentBackground(.hidden).background(Theme.paper) }
}

struct AlongSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 14, content: content)
                .frame(maxWidth: .infinity, alignment: .leading).card(padding: 18)
        }
    }
}

struct SettingsAction: View {
    var title: String
    var symbol: String
    var destructive = false
    var action: () -> Void
    var body: some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            HStack(spacing: 12) {
                AlongIcon(symbol: symbol, apricot: true)
                Text(title).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption)
            }.frame(minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}
