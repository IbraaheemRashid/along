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

/// A round monogram for a peptide in the colour the person chose for it. The
/// monogram stays so colour is never the only cue.
struct PeptideBadge: View {
    var name: String
    var color: PeptideColor
    var size: CGFloat = 44
    var dimmed = false

    var monogram: String {
        let letters = name.filter { $0.isLetter || $0.isNumber }
        return String(letters.prefix(2)).uppercased()
    }

    var body: some View {
        let tint = color.color
        Text(monogram)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(dimmed ? SetupTheme.muted : tint)
            .frame(width: size, height: size)
            .background((dimmed ? SetupTheme.tile : tint.opacity(0.14)), in: Circle())
            .accessibilityHidden(true)
    }
}

/// A small dot in a peptide's colour, for chips, calendars and legends.
struct PeptideDot: View {
    var color: PeptideColor
    var size: CGFloat = 8
    var body: some View {
        Circle().fill(color.color).frame(width: size, height: size).accessibilityHidden(true)
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

/// Reserved for internal sandboxes only — shipping screens no longer show preview chrome.
struct PreviewBadge: View {
    var body: some View { EmptyView() }
}

extension View {
    func appBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity).background(SetupTheme.tile.ignoresSafeArea())
    }
}
