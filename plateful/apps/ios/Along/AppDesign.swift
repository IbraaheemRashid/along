import SwiftUI

/// Shared building blocks for the app behind the paywall, in the same white
/// language as setup.
struct AppCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}

struct AppSectionTitle: View {
    var title: String
    var trailing: String?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, weight: .bold)).foregroundStyle(SetupTheme.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing { Text(trailing).font(.subheadline).foregroundStyle(SetupTheme.muted) }
        }
    }
}

extension PeptideColour {
    var tint: Color {
        switch self {
        case .blue: Color(red: 0.42, green: 0.62, blue: 0.93)
        case .mint: Color(red: 0.36, green: 0.72, blue: 0.56)
        case .rose: Color(red: 0.93, green: 0.55, blue: 0.62)
        case .lilac: Color(red: 0.66, green: 0.55, blue: 0.85)
        case .apricot: Color(red: 0.93, green: 0.65, blue: 0.36)
        case .indigo: Color(red: 0.45, green: 0.52, blue: 0.85)
        case .slate: Color(red: 0.6, green: 0.6, blue: 0.65)
        case .teal: Color(red: 0.20, green: 0.66, blue: 0.68)
        case .gold: Color(red: 0.85, green: 0.70, blue: 0.30)
        }
    }
}

struct PeptideDayDots: View {
    let peptides: [TrackedPeptide]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(peptides.prefix(3)) { peptide in
                Circle().fill(peptide.displayColour.tint).frame(width: 5, height: 5)
            }
            if peptides.count > 3 {
                Text("+\(peptides.count - 3)").font(.system(size: 8, weight: .semibold))
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

struct PeptideBadge: View {
    var name: String
    var colour: PeptideColour
    var size: CGFloat = 44
    var dimmed = false

    var monogram: String {
        let letters = name.filter { $0.isLetter || $0.isNumber }
        return String(letters.prefix(2)).uppercased()
    }

    var body: some View {
        let tint = colour.tint
        Text(monogram)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(tint.opacity(dimmed ? 0.75 : 1))
            .frame(width: size, height: size)
            .background((dimmed ? SetupTheme.tile : tint.opacity(0.14)), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Progress ring. A nil fraction draws a quiet dashed outline: nothing due.
struct DoseRing<Center: View>: View {
    var fraction: Double?
    var lineWidth: CGFloat = 8
    var tint: Color = SetupTheme.ink
    @ViewBuilder var center: Center
    var body: some View {
        ZStack {
            if let fraction {
                Circle().stroke(SetupTheme.tile, lineWidth: lineWidth)
                Circle().trim(from: 0, to: min(1, fraction))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(fraction > 0 ? 1 : 0)
            } else {
                Circle().stroke(SetupTheme.border, style: StrokeStyle(lineWidth: max(1, lineWidth / 4), dash: [3, 3]))
            }
            center
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: fraction)
    }
}

/// States clearly when the app is showing a preview or fictional data.
struct PreviewBadge: View {
    @Environment(JournalStore.self) private var store
    var body: some View {
        if let text {
            Text(text).font(.system(size: 10, weight: .bold)).tracking(0.8)
                .foregroundStyle(SetupTheme.highlight)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(SetupTheme.highlight.opacity(0.12), in: Capsule())
                .accessibilityIdentifier("app.preview-badge")
        }
    }
    private var text: String? {
        if store.journal.hasSampleData { return "SAMPLE DATA" }
        if store.journal.isDesignPreview == true { return "DESIGN PREVIEW · NO SUBSCRIPTION" }
        return nil
    }
}

extension View {
    func appBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity).background(SetupTheme.tile.ignoresSafeArea())
    }
}
