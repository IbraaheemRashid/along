import SwiftUI

/// Visual language for first-run setup: white surface, near-black ink, quiet
/// grey tiles and a single warm highlight for personalised numbers.
enum SetupTheme {
    private static func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    static let surface = dynamic(.white, .black)
    static let ink = dynamic(UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1), .white)
    static let inverseInk = dynamic(.white, UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))
    static let muted = dynamic(UIColor(red: 0.53, green: 0.53, blue: 0.56, alpha: 1), UIColor(red: 0.62, green: 0.62, blue: 0.66, alpha: 1))
    static let tile = dynamic(UIColor(red: 0.965, green: 0.965, blue: 0.98, alpha: 1), UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1))
    static let iconTile = dynamic(UIColor(red: 0.95, green: 0.95, blue: 0.975, alpha: 1), UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1))
    static let border = dynamic(UIColor(red: 0.91, green: 0.91, blue: 0.93, alpha: 1), UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1))
    static let disabled = dynamic(UIColor(red: 0.77, green: 0.77, blue: 0.79, alpha: 1), UIColor(red: 0.27, green: 0.27, blue: 0.29, alpha: 1))
    static let highlight = Color(red: 0.88, green: 0.58, blue: 0.40)
    static let success = Color(red: 0.16, green: 0.66, blue: 0.40)
    static let loader = LinearGradient(colors: [Color(red: 0.93, green: 0.48, blue: 0.53), Color(red: 0.66, green: 0.55, blue: 0.78), Color(red: 0.42, green: 0.62, blue: 0.93)], startPoint: .leading, endPoint: .trailing)
}

private struct SetupTitleFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 32
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold)).tracking(-0.6)
    }
}

extension View {
    func setupTitleFont() -> some View { modifier(SetupTitleFont()) }
}

struct SetupHeading: View {
    var title: String
    var subtitle: String?
    var centered = false
    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 10) {
            Text(title).setupTitleFont().foregroundStyle(SetupTheme.ink)
                .multilineTextAlignment(centered ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.body).foregroundStyle(SetupTheme.muted)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

enum SetupIcon {
    case symbol(String)
    case glyph(String)
}

struct SetupIconTile: View {
    var icon: SetupIcon
    var size: CGFloat = 44
    var body: some View {
        Group {
            switch icon {
            case .symbol(let name): Image(systemName: name).font(.system(size: size * 0.4, weight: .medium))
            case .glyph(let text): Text(text).font(.system(size: size * 0.5, weight: .regular))
            }
        }
        .foregroundStyle(SetupTheme.ink)
        .frame(width: size, height: size)
        .background(SetupTheme.iconTile, in: Circle())
        .accessibilityHidden(true)
    }
}

/// A full-width answer row. Single-choice rows show a radio; multi-choice rows
/// show a check so the difference is visible before tapping.
struct SetupOptionRow: View {
    var title: String
    var detail: String?
    var icon: SetupIcon?
    var selected: Bool
    var multiple = false
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon { SetupIconTile(icon: icon) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(.body, weight: .medium)).foregroundStyle(SetupTheme.ink)
                    if let detail { Text(detail).font(.footnote).foregroundStyle(SetupTheme.muted) }
                }.multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                indicator
            }
            .padding(.horizontal, 16).padding(.vertical, detail == nil ? 10 : 16)
            .frame(maxWidth: .infinity, minHeight: detail == nil ? 62 : 68, alignment: .leading)
            .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? SetupTheme.ink : SetupTheme.border, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(SetupPressStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var indicator: some View {
        if multiple {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(selected ? SetupTheme.ink : SetupTheme.border)
        } else {
            ZStack {
                Circle().strokeBorder(selected ? SetupTheme.ink : SetupTheme.border, lineWidth: 1.5)
                if selected { Circle().fill(SetupTheme.ink); Circle().fill(SetupTheme.inverseInk).frame(width: 8, height: 8) }
            }.frame(width: 23, height: 23)
        }
    }
}

/// Compact tile for long, low-stakes lists so they fit without scrolling.
struct SetupGridOption: View {
    var title: String
    var symbol: String
    var selected: Bool
    var identifier: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SetupIconTile(icon: .symbol(symbol), size: 36)
                Text(title).font(.system(.subheadline, weight: .medium)).foregroundStyle(SetupTheme.ink)
                    .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? SetupTheme.ink : SetupTheme.border, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SetupPressStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SetupPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SetupPrimaryButton: View {
    var title: String
    var symbol: String?
    var enabled = true
    var identifier = "setup.continue"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(enabled ? SetupTheme.inverseInk : Color.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(enabled ? SetupTheme.ink : SetupTheme.disabled, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(SetupPressStyle())
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.15), value: enabled)
        .accessibilityIdentifier(identifier)
    }
}

struct SetupTextButton: View {
    var title: String
    var identifier: String
    var action: () -> Void
    var body: some View {
        Button(title, action: action)
            .font(.system(.body, weight: .medium)).foregroundStyle(SetupTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier(identifier)
    }
}

struct SetupBackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                .frame(width: 44, height: 44).background(SetupTheme.tile, in: Circle())
        }
        .buttonStyle(SetupPressStyle())
        .accessibilityLabel("Back").accessibilityIdentifier("setup.back")
    }
}

struct SetupProgressBar: View {
    var progress: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(SetupTheme.tile)
                Capsule().fill(SetupTheme.ink).frame(width: max(6, proxy.size.width * progress))
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.3), value: progress)
        .accessibilityElement().accessibilityLabel("Setup progress").accessibilityValue("\(Int(progress * 100)) percent")
    }
}

struct SetupUnitToggle: View {
    var left: String
    var right: String
    @Binding var isRight: Bool
    var body: some View {
        HStack(spacing: 0) {
            segment(left, active: !isRight) { isRight = false }
            segment(right, active: isRight) { isRight = true }
        }
        .padding(3).background(SetupTheme.tile, in: Capsule())
        .frame(width: 240)
        .sensoryFeedback(.selection, trigger: isRight)
    }
    private func segment(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(.subheadline, weight: .medium)).foregroundStyle(active ? SetupTheme.ink : SetupTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(active ? SetupTheme.surface : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? SetupTheme.border : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// Horizontal ruler. `value` is in display units; `anchor` shades the span
/// between a starting value and the current selection.
struct SetupRuler: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var anchor: Double?
    var accessibilityLabel: String
    var unit: String
    @State private var position: Int?
    private let spacing: CGFloat = 9

    private var count: Int { Int(((range.upperBound - range.lowerBound) / step).rounded()) }
    private func index(for value: Double) -> Int { min(count, max(0, Int(((value - range.lowerBound) / step).rounded()))) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0...count, id: \.self) { tick($0).id($0) }
                }.scrollTargetLayout()
            }
            .contentMargins(.horizontal, proxy.size.width / 2 - spacing / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .center)
            .overlay {
                Capsule().fill(SetupTheme.ink).frame(width: 3, height: 76).allowsHitTesting(false)
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18), .init(color: .black, location: 0.82), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing))
        }
        .frame(height: 80)
        .onAppear { position = index(for: value) }
        .onChange(of: position) { _, new in
            guard let new else { return }
            value = ((range.lowerBound + Double(new) * step) * 10).rounded() / 10
        }
        .sensoryFeedback(.selection, trigger: position)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(1)))) \(unit)")
        .accessibilityAdjustableAction { direction in
            let current = index(for: value)
            position = direction == .increment ? min(count, current + 1) : max(0, current - 1)
        }
    }

    private func tick(_ index: Int) -> some View {
        let major = index % 10 == 0, mid = index % 5 == 0
        let shaded: Bool = {
            guard let anchor, let position else { return false }
            let start = self.index(for: anchor)
            return (min(start, position)...max(start, position)).contains(index)
        }()
        return ZStack(alignment: .center) {
            if shaded { Rectangle().fill(SetupTheme.tile) }
            Rectangle().fill(major ? SetupTheme.ink : SetupTheme.muted.opacity(mid ? 0.8 : 0.45))
                .frame(width: major ? 1.5 : 1, height: major ? 56 : mid ? 40 : 30)
        }
        .frame(width: spacing, height: 76)
    }
}

/// Wraps chips onto as many lines as needed.
struct SetupFlowLayout: Layout {
    var spacing: CGFloat = 8
    private func measure(_ view: LayoutSubview, width: CGFloat) -> CGSize {
        let ideal = view.sizeThatFits(.unspecified)
        guard ideal.width > width, width.isFinite else { return ideal }
        let fitted = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: min(fitted.width, width), height: fitted.height)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = measure(view, width: width)
            if x > 0 && x + size.width > width { y += row + spacing; x = 0; row = 0 }
            x += size.width + spacing; row = max(row, size.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = measure(view, width: bounds.width)
            if x > bounds.minX && x + size.width > bounds.maxX { y += row + spacing; x = bounds.minX; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}

struct SetupChip: View {
    var title: String
    var detail: String?
    var selected: Bool
    var leading: String?
    /// A colour dot shown in place of the leading symbol, e.g. a peptide's colour.
    var dot: Color? = nil
    var identifier: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(selected ? SetupTheme.inverseInk.opacity(0.9) : .clear, lineWidth: 1.5))
                        .accessibilityHidden(true)
                    if selected { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                } else {
                    Image(systemName: selected ? "checkmark" : (leading ?? "plus")).font(.system(size: 12, weight: .bold))
                }
                Text(title).font(.system(.subheadline, weight: .medium)).lineLimit(1).layoutPriority(1)
                if let detail { Text(detail).font(.caption).foregroundStyle(selected ? SetupTheme.inverseInk.opacity(0.7) : SetupTheme.muted).lineLimit(1) }
            }
            .foregroundStyle(selected ? SetupTheme.inverseInk : SetupTheme.ink)
            .padding(.horizontal, 14).frame(minHeight: 40)
            .background(selected ? SetupTheme.ink : SetupTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? SetupTheme.ink : SetupTheme.border))
            .contentShape(Capsule())
        }
        .buttonStyle(SetupPressStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SetupCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Account sign-in sheet. Provider button chrome is unchanged; taps run real auth.
struct SetupSignInSheet: View {
    var restoreBackup: () -> Void
    var onSignedIn: (() -> Void)? = nil
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showEmailForm = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Sign in").font(.headline).foregroundStyle(SetupTheme.ink)
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SetupTheme.ink)
                            .frame(width: 32, height: 32).background(SetupTheme.tile, in: Circle())
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Close").accessibilityIdentifier("setup.sign-in.close")
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    provider("Sign in with Apple", identifier: "apple", filled: true) {
                        Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium))
                    } action: {
                        Task {
                            await auth.signInWithApple()
                            if auth.isSignedIn { onSignedIn?(); dismiss() }
                        }
                    }
                    provider("Sign in with Google", identifier: "google", filled: false) {
                        Text("G").font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.92, green: 0.26, blue: 0.21), Color(red: 0.98, green: 0.74, blue: 0.02), Color(red: 0.2, green: 0.66, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    } action: {
                        Task {
                            await auth.signInWithGoogle()
                            if auth.isSignedIn { onSignedIn?(); dismiss() }
                        }
                    }
                    provider("Continue with email", identifier: "email", filled: false) {
                        Image(systemName: "envelope").font(.system(size: 17, weight: .medium))
                    } action: {
                        showEmailForm = true
                        auth.beginEmailSignIn()
                    }
                    if showEmailForm {
                        AlongFormField(text: $email, kind: .email, placeholder: "Email", identifier: "setup.sign-in.email.field")
                        AlongFormField(text: $password, kind: .password, placeholder: "Password", identifier: "setup.sign-in.password.field", onSubmit: submitEmail)
                        Button(action: submitEmail) {
                            Text(auth.isBusy ? "Please wait…" : "Continue")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(SetupTheme.inverseInk)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(SetupTheme.ink, in: Capsule())
                        }
                        .disabled(auth.isBusy)
                        .accessibilityIdentifier("setup.sign-in.email.submit")
                    }
                    if let notice = auth.message {
                        Text(notice).font(.footnote).foregroundStyle(SetupTheme.muted).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("setup.sign-in.notice")
                    }
                }
                .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 8)
                .disabled(auth.isBusy)
            }
            Button(action: restoreBackup) {
                (Text("Have a backup file? ").foregroundStyle(SetupTheme.muted) + Text("Restore it").fontWeight(.semibold).foregroundStyle(SetupTheme.ink))
                    .font(.footnote).frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityIdentifier("setup.restore-backup")
            .padding(.bottom, 6)
        }
        .background(SetupTheme.surface)
        .ignoresSafeArea(.keyboard)
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
        .onAppear {
            email = auth.emailDraft
            showEmailForm = auth.showsEmailForm
        }
    }

    private func submitEmail() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        auth.stageOnboardingCredentials(email: email, password: password)
        Task {
            await auth.submitEmailSignIn()
            if auth.isSignedIn { onSignedIn?(); dismiss() }
        }
    }

    private func provider<Icon: View>(_ title: String, identifier: String, filled: Bool, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon().frame(width: 22)
                Text(title).font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(filled ? SetupTheme.inverseInk : SetupTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(filled ? SetupTheme.ink : SetupTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(filled ? Color.clear : SetupTheme.border, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(SetupPressStyle())
        .accessibilityIdentifier("setup.sign-in.\(identifier)")
    }
}
