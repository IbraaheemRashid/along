import Charts
import SwiftUI

/// Health tab: Apple Health samples composed into one status surface — not a
/// grid of metric cards. Tracking / visualisation only.
struct HealthDashboardView: View {
    @Environment(JournalStore.self) private var store
    @Environment(HealthKitStore.self) private var health
    @Environment(\.alongReducedMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var window: Window = .month
    @State private var appeared = false

    private enum Window: Int, CaseIterable, Identifiable {
        case week = 7, month = 30
        var id: Int { rawValue }
        var title: String { self == .week ? "7 days" : "30 days" }
    }

    private var goals: Set<SetupGoal> { store.journal.setupProfile?.goals ?? [] }
    private var insight: HealthInsight {
        HealthAnalytics.insight(
            from: health.snapshot,
            goals: goals,
            window: window.rawValue,
            todayKey: store.todayKey
        )
    }
    private var latest: HealthDay? { health.snapshot.latest }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 18)

                composition
                    .padding(.horizontal, 16)

                if let message = health.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(SetupTheme.muted)
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                }

                ribbon
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 36)
            }
        }
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(
                colors: [
                    SetupTheme.surface,
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    SetupTheme.tile
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .task { await health.refresh() }
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
        .accessibilityIdentifier("health.dashboard")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Health").font(.system(size: 30, weight: .bold)).tracking(-0.6).foregroundStyle(SetupTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(health.snapshot.source == .healthKit ? "From Apple Health" : "Preview · connect Apple Health")
                    .font(.caption.weight(.medium)).foregroundStyle(SetupTheme.muted)
            }
            Spacer()
            windowPicker
            PreviewBadge()
        }
    }

    private var windowPicker: some View {
        HStack(spacing: 0) {
            ForEach(Window.allCases) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { window = option }
                } label: {
                    Text(option.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(window == option ? SetupTheme.inverseInk : SetupTheme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(window == option ? SetupTheme.ink : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(window == option ? .isSelected : [])
                .accessibilityIdentifier("health.window.\(option.rawValue)")
            }
        }
        .padding(3)
        .background(SetupTheme.surface.opacity(0.9), in: Capsule())
        .overlay(Capsule().strokeBorder(SetupTheme.border))
    }

    /// One continuous panel: status, projection labels, and the multi-series chart.
    private var composition: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                statusRing
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.headline)
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(SetupTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                    Text(insight.detail)
                        .font(.subheadline)
                        .foregroundStyle(SetupTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Label(insight.currentLabel, systemImage: "circle.fill")
                        Label(insight.projectedLabel, systemImage: "arrow.triangle.branch")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SetupTheme.ink.opacity(0.75))
                    .labelStyle(.titleAndIcon)
                    .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 8)

            chart
                .frame(height: 210)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .opacity(appeared ? 1 : 0)

            if health.canRequestAccess && health.snapshot.source != .healthKit {
                Button {
                    Task { await health.refresh() }
                } label: {
                    Text(health.isLoading ? "Opening Apple Health…" : "Connect Apple Health")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(SetupTheme.ink)
                .background(SetupTheme.surface.opacity(0.55))
                .accessibilityIdentifier("health.connect")
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.95, blue: 0.98),
                            Color(red: 0.97, green: 0.94, blue: 0.91),
                            SetupTheme.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(SetupTheme.border.opacity(0.8))
                )
                .shadow(color: .black.opacity(0.06), radius: 24, y: 12)
        }
        .accessibilityIdentifier("health.composition")
    }

    private var statusRing: some View {
        let score = insight.overallScore
        return DoseRing(fraction: score.map { $0 / 100 }, lineWidth: 10, tint: ringTint(score)) {
            VStack(spacing: 2) {
                Text(score.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SetupTheme.ink)
                    .contentTransition(.numericText())
                Text("blend").font(.caption2.weight(.medium)).foregroundStyle(SetupTheme.muted)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel(score.map { "Blended health score \($0.rounded())" } ?? "No blended score yet")
        .accessibilityIdentifier("health.score")
    }

    private func ringTint(_ score: Double?) -> Color {
        guard let score else { return SetupTheme.muted }
        if score >= 70 { return Color(red: 0.22, green: 0.62, blue: 0.48) }
        if score >= 45 { return SetupTheme.highlight }
        return Color(red: 0.75, green: 0.45, blue: 0.42)
    }

    private var chart: some View {
        let points = insight.series + insight.projection
        return Chart(points) { point in
            if point.series == .projection {
                LineMark(
                    x: .value("Day", point.dayKey),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(SetupTheme.ink.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .interpolationMethod(.catmullRom)
            } else {
                LineMark(
                    x: .value("Day", point.dayKey),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(by: .value("Series", seriesTitle(point.series)))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.4))

                AreaMark(
                    x: .value("Day", point.dayKey),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(by: .value("Series", seriesTitle(point.series)))
                .opacity(0.08)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale([
            "Activity": Color(red: 0.30, green: 0.55, blue: 0.92),
            "Recovery": Color(red: 0.28, green: 0.68, blue: 0.52),
            "Sleep": Color(red: 0.62, green: 0.48, blue: 0.88)
        ])
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(SetupTheme.muted)
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                AxisValueLabel {
                    if let n = value.as(Int.self) {
                        Text("\(n)").font(.caption2).foregroundStyle(SetupTheme.muted)
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
        .padding(12)
        .accessibilityIdentifier("health.chart")
    }

    private func seriesTitle(_ series: HealthChartPoint.Series) -> String {
        switch series {
        case .activity: "Activity"
        case .recovery: "Recovery"
        case .sleep: "Sleep"
        case .projection: "Projection"
        }
    }

    /// Inline metric ribbon — one strip, every stat visible without scrolling.
    /// Five equal columns; at accessibility text sizes it wraps to 3 + 2 rows.
    private var ribbon: some View {
        let steps = metric("Steps", value: latest?.steps.map { $0.formatted(.number.precision(.fractionLength(0))) }, unit: nil, symbol: "figure.walk")
        let active = metric("Active", value: latest?.activeEnergyKcal.map { "\(Int($0.rounded()))" }, unit: " kcal", symbol: "flame")
        let sleep = metric("Sleep", value: latest?.sleepHours.map { String(format: "%.1f", $0) }, unit: "h", symbol: "moon.zzz")
        let hrv = metric("HRV", value: latest?.hrvSDNN.map { "\(Int($0.rounded()))" }, unit: " ms", symbol: "waveform.path.ecg")
        let resting = metric("Resting", value: latest?.restingHeartRate.map { "\(Int($0.rounded()))" }, unit: " bpm", symbol: "heart")
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Today’s stats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SetupTheme.muted)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        HStack(spacing: 0) { steps; divider; active; divider; sleep }
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle().fill(SetupTheme.border).frame(height: 1).padding(.horizontal, 12)
                        HStack(spacing: 0) { hrv; divider; resting }
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(spacing: 0) { steps; divider; active; divider; sleep; divider; hrv; divider; resting }
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(SetupTheme.surface.opacity(0.7), in: shape)
            .overlay(shape.strokeBorder(SetupTheme.border.opacity(0.7)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("health.ribbon")
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(SetupTheme.border)
            .frame(width: 1)
            .padding(.vertical, 6)
    }

    private func metric(_ title: String, value: String?, unit: String?, symbol: String) -> some View {
        let number = Text(value ?? "—").font(.subheadline.weight(.semibold))
        let suffix = Text(value == nil ? "" : unit ?? "").font(.caption2.weight(.medium))
        return VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SetupTheme.ink.opacity(0.7))
            Text("\(number)\(suffix)")
                .foregroundStyle(SetupTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.4 : 0.6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(SetupTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }
}
