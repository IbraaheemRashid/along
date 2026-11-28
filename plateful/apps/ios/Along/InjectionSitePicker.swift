import SwiftUI

/// Full-screen 3D injection-site picker, shown after a peptide is chosen.
/// Spin the body, tap an area to zoom in, then tap an exact spot. Heat shows
/// past logs only — Along never suggests where to inject.
struct InjectionSitePicker: View {
    var peptideName: String
    var heat: SpotHeat
    var lastSpot: InjectionSpot?
    var initial: InjectionSpot?
    /// Interactive teaching surface in setup — same 3D body, no log/save chrome.
    var isDemo = false
    /// Called with the chosen spot, or nil when the person skips the site.
    var onFinish: (InjectionSpot?) -> Void
    var onCancel: () -> Void

    @Environment(\.alongReducedMotion) private var reduceMotion
    @State private var model = BodySceneModel()
    @State private var selected: InjectionSpot?
    @State private var side: BodySide = .left

    static let cool = Color(red: 0.72, green: 0.82, blue: 0.78)
    static let warm = Color(red: 0.92, green: 0.78, blue: 0.48)
    static let hot = Color(red: 0.86, green: 0.42, blue: 0.36)
    /// Ink for anything drawn over the 3D body, which stays light in dark mode.
    /// Matches `SetupTheme.ink` in light mode.
    static let onBody = Color(red: 0.07, green: 0.07, blue: 0.09)

    private var focusedRegion: BodyRegion? { model.focusedArea?.region }

    var body: some View {
        VStack(spacing: 0) {
            header
            tile
                .padding(.horizontal, 16)
            areaChips
                .padding(.top, 12)
            footer
        }
        .background(SetupTheme.surface)
        .onAppear {
            model.reduceMotion = reduceMotion
            if let initial {
                selected = initial
                side = initial.side
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.focus(areaID: initial.areaID) }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            if isDemo {
                Text("Try the body map").font(.headline).foregroundStyle(SetupTheme.ink)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
            } else {
                ZStack {
                    Text("Injection site").font(.headline).foregroundStyle(SetupTheme.ink)
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold)).foregroundStyle(SetupTheme.ink)
                                .frame(width: 36, height: 36).background(SetupTheme.tile, in: Circle())
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Back").accessibilityIdentifier("site.cancel")
                        Spacer()
                        Button("Skip") { onFinish(nil) }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.muted)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityHint("Log this dose without a site")
                            .accessibilityIdentifier("site.skip")
                    }
                }
                HStack(spacing: 8) {
                    Text(peptideName)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.inverseInk)
                        .padding(.horizontal, 14).frame(minHeight: 34)
                        .background(SetupTheme.ink, in: Capsule())
                    Spacer()
                    if let lastSpot {
                        Text("Last: \(lastSpot.shortTitle)").font(.caption.weight(.medium)).foregroundStyle(SetupTheme.muted)
                            .accessibilityIdentifier("site.last")
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)
    }

    // MARK: Tile

    private var tile: some View {
        ZStack {
            if model.isAvailable {
                BodySceneView(model: model, background: UIColor(SetupTheme.tile)) { area in
                    if area.side != nil { side = area.side ?? side }
                    model.focus(area)
                }
                spotOverlay
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.stand").font(.system(size: 40)).foregroundStyle(SetupTheme.muted)
                    Text("The 3D body couldn’t load. Pick an area below.").font(.footnote).foregroundStyle(SetupTheme.muted)
                }
            }
            VStack {
                HStack {
                    if model.focusedArea != nil {
                        Button { selected = nil; model.showWholeBody() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                                Text("Whole body").font(.footnote.weight(.semibold))
                            }
                            .foregroundStyle(SetupTheme.ink)
                            .padding(.horizontal, 12).frame(minHeight: 36)
                            .background(SetupTheme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(SetupTheme.border))
                        }
                        .accessibilityIdentifier("site.whole-body")
                        .transition(.opacity)
                    }
                    Spacer()
                }
                Spacer()
                if model.focusedArea == nil {
                    Text(model.viewLabel).font(.caption.weight(.semibold)).foregroundStyle(SetupTheme.muted)
                        .accessibilityIdentifier("site.view")
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SetupTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(SetupTheme.border))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.focusedArea?.id)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("site.body")
    }

    private var spotOverlay: some View {
        ZStack {
            if model.spotsVisible, let area = model.focusedArea {
                if area.region == .abdomen { quadrantLabels(area) }
                ForEach(Array(area.spots.enumerated()), id: \.element.id) { offset, raw in
                    if let spot = InjectionSpot(id: raw.id), let point = model.spotPoints[raw.id] {
                        Button { selected = spot } label: {
                            SpotDot(count: heat.count(for: spot), isLast: spot == lastSpot, isSelected: spot == selected)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(spot == selected ? .isSelected : [])
                        .accessibilityLabel(spot.title)
                        .accessibilityValue(heat.historyText(for: spot) + (spot == lastSpot ? ", used last time" : ""))
                        .accessibilityIdentifier("site.spot.\(spot.id)")
                        .position(point)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7).delay(Double(offset) * 0.025), value: model.spotsVisible)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: model.spotsVisible)
    }

    private func quadrantLabels(_ area: BodySiteManifest.Area) -> some View {
        ForEach(AbdomenQuadrant.allCases) { quadrant in
            ForEach(BodySide.allCases) { side in
                let ids = area.spots.map(\.id).filter { $0.hasPrefix("abdomen.\(side.rawValue).\(quadrant.rawValue).") }
                let points = ids.compactMap { model.spotPoints[$0] }
                if !points.isEmpty {
                    let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
                    let y = quadrant == .upper ? (points.map(\.y).min() ?? 0) - 30 : (points.map(\.y).max() ?? 0) + 30
                    Text("\(quadrant.title) \(side.rawValue)")
                        .font(.caption.weight(.semibold)).foregroundStyle(Self.onBody.opacity(0.75))
                        .position(x: x, y: y)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Areas

    private var areaChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BodyRegion.allCases) { region in
                    SetupChip(title: region.title, selected: focusedRegion == region, leading: "circle.fill",
                              identifier: "site.area.\(region.rawValue)") {
                        selected = nil
                        model.focus(areaID: region.isSided ? "\(region.rawValue).\(side.rawValue)" : region.rawValue)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if let area = model.focusedArea {
            card(area)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    legend(Self.cool, "Cool"); legend(Self.warm, "Warm"); legend(Self.hot, "Often used")
                    Spacer(minLength: 0)
                    Text("Drag to rotate · tap an area").font(.caption).foregroundStyle(SetupTheme.muted)
                }
                Text(isDemo
                     ? "This is the same map you’ll use when logging a dose. Heat builds from your own history — Along never chooses a site for you."
                     : "Optional. Heat shows where you’ve logged recently so you can rotate sites yourself — Along never picks one for you.")
                    .font(.caption).foregroundStyle(SetupTheme.muted)
            }
            .padding(.horizontal, 22).padding(.vertical, 16)
        }
    }

    private func card(_ area: BodySiteManifest.Area) -> some View {
        let spotCount = area.spots.count
        let title = selected.map { s in s.region == .abdomen ? "Abdomen · \(s.quadrantTitle ?? "")" : "\(s.region.title) · \(s.side.title)" }
            ?? (area.side.map { "\(area.region.title) · \($0.title)" } ?? area.region.title)
        let subtitle = selected.map { "Spot \($0.index) · \(heat.historyText(for: $0))" }
            ?? (area.region == .abdomen ? "4 quadrants · \(spotCount) spots · tap one" : "\(spotCount) spots · tap one")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(SetupTheme.ink)
                        .accessibilityIdentifier("site.card.title")
                    Text(subtitle).font(.footnote).foregroundStyle(SetupTheme.muted)
                }
                Spacer()
                if area.region.isSided { sideToggle(area.region) }
            }
            if !isDemo {
                SetupPrimaryButton(title: selected == nil ? "Choose a spot" : "Use this spot", enabled: selected != nil,
                                   identifier: "site.use") {
                    if let selected { onFinish(selected) }
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 12)
        .background(SetupTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(SetupTheme.border).frame(height: 1) }
    }

    private func sideToggle(_ region: BodyRegion) -> some View {
        HStack(spacing: 0) {
            ForEach(BodySide.allCases) { value in
                Button {
                    guard side != value else { return }
                    side = value
                    selected = nil
                    model.focus(areaID: "\(region.rawValue).\(value.rawValue)")
                } label: {
                    Text(value.title).font(.footnote.weight(.semibold))
                        .foregroundStyle(side == value ? SetupTheme.inverseInk : SetupTheme.ink)
                        .padding(.horizontal, 14).frame(minHeight: 34)
                        .background(side == value ? SetupTheme.ink : Color.clear, in: Capsule())
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityAddTraits(side == value ? .isSelected : [])
                .accessibilityIdentifier("site.side.\(value.rawValue)")
            }
        }
        .padding(.horizontal, 3)
        .background { Capsule().fill(SetupTheme.tile).padding(.vertical, 2) }
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(SetupTheme.muted)
        }
    }
}

/// One tappable spot: white when unused lately, then cool → warm → often used.
private struct SpotDot: View {
    var count: Int
    var isLast: Bool
    var isSelected: Bool

    private var fill: Color {
        if isSelected { return InjectionSitePicker.onBody }
        switch count {
        case 0: return .white
        case 1: return InjectionSitePicker.cool
        case 2: return InjectionSitePicker.warm
        default: return InjectionSitePicker.hot
        }
    }

    var body: some View {
        let size: CGFloat = isSelected ? 38 : 32
        ZStack {
            Circle().fill(fill)
                .overlay(Circle().strokeBorder(isSelected ? InjectionSitePicker.onBody : .white, lineWidth: isSelected ? 3 : 2))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            if isSelected {
                Circle().strokeBorder(InjectionSitePicker.onBody, lineWidth: 2).frame(width: size + 12, height: size + 12)
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            } else if isLast {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 13, weight: .bold)).foregroundStyle(InjectionSitePicker.onBody)
            } else if count > 0 {
                Text("\(count)").font(.system(size: 13, weight: .bold)).foregroundStyle(InjectionSitePicker.onBody)
            }
        }
        .frame(width: size, height: size)
        .frame(width: 48, height: 48)
        .contentShape(Circle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
