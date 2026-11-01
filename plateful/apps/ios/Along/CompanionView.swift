import SwiftUI

struct CompanionView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text("\(store.companionName)’s place").alongTitle(27); Spacer(); DemoBadge() }
                        VStack(alignment: .leading, spacing: 8) { Text("\(store.companionName)’s place").alongTitle(27); DemoBadge() }
                    }
                    PipRoomView(accessory: store.journal.accessory, height: 235)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .accessibilityElement().accessibilityLabel("\(store.companionName) wearing \(store.journal.accessory.title)")
                        .accessibilityIdentifier("companion.preview")
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(title: "A little more personality", subtitle: "Keepsakes appear as you record days. Once unlocked, they’re yours.")
                        if textSize.isAccessibilitySize {
                            VStack(spacing: 12) { ForEach(Accessory.allCases) { keepsake($0, compact: false) } }
                        } else {
                            HStack(alignment: .top, spacing: 10) { ForEach(Accessory.allCases) { keepsake($0, compact: true) } }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A little friend\nfor the everyday.").alongTitle(27)
                        Text("Meet \(store.companionName). Curious, kind, and always happy to see you.").foregroundStyle(Theme.secondaryInk)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "quote.opening").font(.title2).foregroundStyle(Theme.peach)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("I collect little moments. A new path. A quiet morning. The days we just showed up.")
                                .font(.system(.body, design: .serif)).lineSpacing(4)
                            Text("— \(store.companionName)").font(.caption).foregroundStyle(Theme.secondaryInk)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).card()
                    VStack(alignment: .leading, spacing: 11) {
                        Label("Always on your side", systemImage: "heart").font(.headline)
                        Text("\(store.companionName) never loses progress or gets upset when you’re away. There are no rewards for weight changes, eating less or taking medication.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        Text("A fictional companion for reflection, not a person, clinician or emergency service.")
                            .font(.caption).foregroundStyle(Theme.secondaryInk)
                    }.card()
                }.padding(22).padding(.bottom, 20).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground()
                .navigationTitle(store.companionName).navigationBarTitleDisplayMode(.inline)
        }
    }

    private func keepsake(_ accessory: Accessory, compact: Bool) -> some View {
        let available = store.journal.canUse(accessory)
        let selected = store.journal.accessory == accessory
        return Button {
            guard available else { return }
            store.journal.accessory = accessory
            store.persist()
            store.showToast("\(store.companionName)’s new look")
        } label: {
            let layout = compact ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 16))
            layout {
                PipArtwork(accessory: accessory).frame(width: compact ? 82 : 90, height: 88)
                    .opacity(available ? 1 : 0.55)
                VStack(alignment: compact ? .center : .leading, spacing: 6) {
                    Text(accessory.title).font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Label(available ? (selected ? "Wearing" : "Yours to keep") : "\(accessory.requiredDays) recorded days",
                          systemImage: available ? (selected ? "checkmark.circle.fill" : "circle") : "lock.fill")
                        .font(.caption2).foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !compact { Spacer(minLength: 0) }
            }.frame(maxWidth: .infinity).padding(.horizontal, compact ? 8 : 16).padding(.vertical, 14)
                .background(selected ? Theme.lilac.opacity(0.4) : Theme.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain).disabled(!available)
            .accessibilityIdentifier("companion.accessory.\(accessory.rawValue)")
            .accessibilityLabel("\(accessory.title), \(available ? (selected ? "selected" : "available") : "unlocks after \(accessory.requiredDays) recorded days")")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
