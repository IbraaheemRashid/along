import SwiftUI

/// Interactive body silhouette for logging pin sites. Rotate to see front and
/// back; heat shows where you’ve logged recently. Tracking only — never a
/// recommendation of where to inject.
struct BodyMapView: View {
    @Binding var selection: InjectionSite?
    var heat: SiteHeat = SiteHeat()
    var lastSite: InjectionSite? = nil
    var interactive = true
    var autoRotate: Bool = true
    var accessibilityPrefix = "body.site"

    @Environment(\.alongReducedMotion) private var reduceMotion
    @State private var yaw: Double = 12
    @State private var dragStart: Double?

    private var showingBack: Bool {
        let normalized = abs(yaw.truncatingRemainder(dividingBy: 360))
        let folded = normalized > 180 ? 360 - normalized : normalized
        return folded > 90
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [SetupTheme.tile, SetupTheme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(SetupTheme.border)
                    )

                figure
                    .frame(maxWidth: 220, maxHeight: 340)
                    .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
                    .padding(.vertical, 18)

                VStack {
                    Spacer()
                    Text(showingBack ? "Back" : "Front")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SetupTheme.muted)
                        .padding(.bottom, 14)
                }
            }
            .frame(height: 360)
            .gesture(interactive ? drag : nil)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("body.map")
            .onAppear {
                guard autoRotate, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                    yaw = -18
                }
            }

            legend
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStart == nil { dragStart = yaw }
                yaw = (dragStart ?? 0) + value.translation.width * 0.45
            }
            .onEnded { _ in
                dragStart = nil
                // Settle near front (±20) or back (±180) so hotspots stay readable.
                let target: Double
                if showingBack {
                    target = yaw >= 0 ? 180 : -180
                } else {
                    target = yaw >= 0 ? 18 : -18
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { yaw = target }
            }
    }

    private var figure: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                BodySilhouette(back: showingBack)
                    .fill(SetupTheme.ink.opacity(0.08))
                    .overlay(BodySilhouette(back: showingBack).stroke(SetupTheme.ink.opacity(0.22), lineWidth: 1.5))

                ForEach(visibleSites) { site in
                    hotspot(site, in: size)
                }
            }
        }
    }

    private var visibleSites: [InjectionSite] {
        InjectionSite.allCases.filter { $0.isBack == showingBack }
    }

    private func hotspot(_ site: InjectionSite, in size: CGSize) -> some View {
        let point = site.bodyPoint
        let intensity = heat.intensity(for: site)
        let selected = selection == site
        let diameter: CGFloat = selected ? 34 : 28
        return Button {
            guard interactive else { return }
            selection = selection == site ? nil : site
        } label: {
            ZStack {
                Circle()
                    .fill(heatColor(intensity).opacity(selected ? 0.95 : 0.55 + intensity * 0.35))
                    .frame(width: diameter, height: diameter)
                    .overlay(Circle().strokeBorder(selected ? SetupTheme.ink : .white.opacity(0.7), lineWidth: selected ? 2.5 : 1))
                    .shadow(color: heatColor(intensity).opacity(0.35), radius: selected ? 8 : 4)
                if site == lastSite {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selected ? SetupTheme.inverseInk : SetupTheme.ink.opacity(0.75))
                } else if heat.count(for: site) > 0 {
                    Text("\(heat.count(for: site))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selected ? SetupTheme.inverseInk : SetupTheme.ink)
                }
            }
            .contentShape(Circle().scale(1.4))
        }
        .buttonStyle(.plain)
        .position(x: point.x * size.width, y: point.y * size.height)
        .accessibilityLabel(site.title + (site == lastSite ? ", used last time" : "") + heatLabel(site))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("\(accessibilityPrefix).\(site.rawValue)")
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func heatColor(_ intensity: Double) -> Color {
        if intensity <= 0 { return SetupTheme.tile }
        if intensity < 0.34 { return Color(red: 0.72, green: 0.82, blue: 0.78) }
        if intensity < 0.67 { return Color(red: 0.92, green: 0.78, blue: 0.48) }
        return Color(red: 0.86, green: 0.42, blue: 0.36)
    }

    private func heatLabel(_ site: InjectionSite) -> String {
        let n = heat.count(for: site)
        return n == 0 ? "" : ", logged \(n) recent \(n == 1 ? "time" : "times")"
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendSwatch(Color(red: 0.72, green: 0.82, blue: 0.78), "Cool")
            legendSwatch(Color(red: 0.92, green: 0.78, blue: 0.48), "Warm")
            legendSwatch(Color(red: 0.86, green: 0.42, blue: 0.36), "Often used")
            Spacer(minLength: 0)
            Text("Drag to rotate")
                .font(.caption).foregroundStyle(SetupTheme.muted)
        }
    }

    private func legendSwatch(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(SetupTheme.muted)
        }
    }
}

/// Demo heat for onboarding — illustrative only, not the person's history.
struct PinMapOnboardingDemo: View {
    var reduceMotion: Bool
    @State private var selection: InjectionSite? = .abdomenLeft

    private var demoHeat: SiteHeat {
        var heat = SiteHeat()
        heat.counts = [
            .abdomenLeft: 5, .abdomenRight: 2, .thighLeft: 1, .thighRight: 3,
            .armLeft: 0, .armRight: 1, .gluteLeft: 2, .gluteRight: 0
        ]
        heat.lastUsed[.abdomenLeft] = .now
        return heat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BodyMapView(
                selection: $selection,
                heat: demoHeat,
                lastSite: .abdomenLeft,
                autoRotate: !reduceMotion,
                accessibilityPrefix: "setup.pin"
            )
            if let selection {
                Text("Selected · \(selection.title)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SetupTheme.ink)
                    .accessibilityIdentifier("setup.pin.selected")
            }
            Text("This is a walkthrough with sample heat. Your real map fills in as you log doses.")
                .font(.caption).foregroundStyle(SetupTheme.muted)
        }
    }
}

/// Simple anatomical silhouette. Front and back share the torso outline; back
/// softens the chest notch so glute hotspots read clearly.
private struct BodySilhouette: Shape {
    var back: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        // Head
        path.addEllipse(in: CGRect(x: w * 0.38, y: h * 0.02, width: w * 0.24, height: h * 0.12))
        // Neck → shoulders → arms → torso → legs
        path.move(to: CGPoint(x: w * 0.46, y: h * 0.13))
        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.22)) // left shoulder
        path.addLine(to: CGPoint(x: w * 0.06, y: h * 0.38)) // left hand
        path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.42)) // left waist
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.58)) // left hip
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.96)) // left foot
        path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.62))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.62))
        path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.22))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.13))
        path.closeSubpath()
        if !back {
            // Soft chest guide on the front face.
            path.move(to: CGPoint(x: w * 0.42, y: h * 0.30))
            path.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.30), control: CGPoint(x: w * 0.50, y: h * 0.34))
        }
        return path
    }
}
