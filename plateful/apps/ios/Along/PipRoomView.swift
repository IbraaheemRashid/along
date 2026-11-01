import SwiftUI

/// Along's reading nook. All artwork is drawn locally using our existing palette.
/// The character assets remain the original Pip renders.
struct PipRoomView: View {
    var accessory: Accessory
    var message: String? = nil
    var height: CGFloat = 250
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(spacing: 0) {
            if textSize.isAccessibilitySize, let message { speech(message).padding(16) }
            GeometryReader { geometry in
                let width = geometry.size.width
                let roomHeight = geometry.size.height
                let hasBubble = message != nil && !textSize.isAccessibilitySize
                ZStack {
                    Theme.paper
                    Theme.lilac.opacity(scheme == .dark ? 0.13 : 0.6)
                    RoomFloor().fill(Theme.peach.opacity(scheme == .dark ? 0.25 : 0.32))
                    Rectangle().fill(Theme.plum.opacity(0.07)).frame(height: 2).offset(y: roomHeight * 0.19)

                    window.frame(width: width * 0.23, height: roomHeight * 0.45)
                        .position(x: width * 0.2, y: roomHeight * 0.47)

                    books.frame(width: width * 0.15, height: roomHeight * 0.17)
                        .position(x: width * 0.83, y: roomHeight * 0.65)
                    Ellipse().fill(Theme.plum.opacity(0.08))
                        .frame(width: width * 0.53, height: roomHeight * 0.16)
                        .position(x: width * 0.55, y: roomHeight * 0.88)
                    Ellipse().stroke(Theme.paper.opacity(0.5), lineWidth: 2)
                        .frame(width: width * 0.46, height: roomHeight * 0.11)
                        .position(x: width * 0.55, y: roomHeight * 0.88)
                    PipArtwork(accessory: accessory)
                        .frame(width: roomHeight * (hasBubble ? 0.74 : 0.88), height: roomHeight * (hasBubble ? 0.74 : 0.88))
                        .position(x: width * 0.55, y: roomHeight * (hasBubble ? 0.64 : 0.57))
                }.clipped().accessibilityHidden(true)
                    .overlay(alignment: .top) {
                        if !textSize.isAccessibilitySize, let message {
                            speech(message).frame(maxWidth: width * 0.78).padding(.top, 12)
                        }
                    }
            }.frame(height: height)
        }.background(Theme.paper)
    }

    private func speech(_ message: String) -> some View {
        Text(message).font(.system(.caption, design: .rounded, weight: .medium))
            .foregroundStyle(Theme.accent).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.card)
                    .frame(width: 11, height: 11).rotationEffect(.degrees(45)).offset(y: 4)
            }
    }

    private var window: some View {
        let arch = UnevenRoundedRectangle(topLeadingRadius: 42, bottomLeadingRadius: 5, bottomTrailingRadius: 5, topTrailingRadius: 42)
        return ZStack {
            arch.fill(Theme.card)
            ZStack {
                (scheme == .dark ? Theme.plum : Theme.lilac)
                Circle().fill(Theme.gold).frame(width: 23, height: 23).offset(x: 16, y: -22)
                Ellipse().fill(Theme.peach.opacity(0.75)).frame(width: 130, height: 65).offset(x: 20, y: 53)
                Rectangle().fill(Theme.card).frame(width: 5)
                Rectangle().fill(Theme.card).frame(height: 5).offset(y: 12)
            }.clipShape(arch).padding(7)
        }.overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3).fill(Theme.card).frame(height: 8).padding(.horizontal, -6)
        }
    }

    private var books: some View {
        VStack(spacing: 3) {
            HStack(alignment: .bottom, spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(Theme.plum).frame(width: 13, height: 30)
                RoundedRectangle(cornerRadius: 3).fill(Theme.peach).frame(width: 12, height: 36)
                RoundedRectangle(cornerRadius: 3).fill(Theme.gold).frame(width: 11, height: 27).rotationEffect(.degrees(-9))
            }
            RoundedRectangle(cornerRadius: 3).fill(Theme.plum.opacity(0.45)).frame(height: 5)
        }
    }
}

private struct RoomFloor: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * 0.7))
            path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height * 0.7), control: CGPoint(x: rect.midX, y: rect.height * 0.64))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
