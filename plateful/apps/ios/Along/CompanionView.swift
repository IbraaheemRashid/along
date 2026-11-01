import SwiftUI

struct CompanionView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var story: PipStory?
    @State private var previewAccessory: Accessory?
    @State private var reward: PipReward?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text("\(store.companionName)’s place").alongTitle(27); Spacer(); DemoBadge() }
                        VStack(alignment: .leading, spacing: 8) { Text("\(store.companionName)’s place").alongTitle(27); DemoBadge() }
                    }
                    PipPlayground(name: store.companionName, accessory: previewAccessory ?? store.journal.accessory, message: "It’s lovely to see you.", height: 235, rewards: store.journal.roomRewards)
                        .accessibilityIdentifier("companion.preview")
                    if let previewAccessory {
                        SetupNote(text: "Previewing \(previewAccessory.title). It becomes yours after \(previewAccessory.requiredDays) recorded days.", symbol: "eye")
                        Button("Back to current look") { self.previewAccessory = nil }.frame(minHeight: 44)
                    }
                    PipProgressCard()
                    Button {
                        story = PipStory.all.first { store.journal.canRead($0) && store.journal.companionDiscoveries?[$0.id] == nil } ?? PipStory.all[0]
                    } label: {
                        HStack(spacing: 14) {
                            AlongIcon(symbol: "bubble.left.and.bubble.right", apricot: true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("A moment with \(store.companionName)").font(.system(.headline, design: .rounded))
                                Text(PipStory.all.contains { store.journal.canRead($0) && store.journal.companionDiscoveries?[$0.id] == nil } ? "A new story is ready for you." : "Revisit a favourite little discovery.").font(.caption).foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
                        }.card(padding: 16)
                    }.buttonStyle(.plain).accessibilityIdentifier("pet.story.open")
                    if let nextStory = PipStory.all.first(where: { !store.journal.canRead($0) }) {
                        Text("Next story: \(nextStory.title) · \(nextStory.requiredDays) recorded days")
                            .font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(title: "A little more personality", subtitle: "Keepsakes appear as you record days. Once unlocked, they’re yours.")
                        if textSize.isAccessibilitySize {
                            VStack(spacing: 12) { ForEach(Accessory.allCases) { keepsake($0, compact: false) } }
                        } else {
                            HStack(alignment: .top, spacing: 10) { ForEach(Accessory.allCases) { keepsake($0, compact: true) } }
                        }
                    }
                    SectionLabel(title: "A room that grows with you", subtitle: "Keep a little record. Make a little home.")
                    ForEach(PipReward.allCases.filter { $0.accessory == nil }) { item in
                        Button { reward = item } label: {
                            HStack(spacing: 14) {
                                AlongIcon(symbol: item.symbol, apricot: true)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.subheadline.weight(.semibold))
                                    Text(store.journal.roomRewards.contains(item) ? "In your room" : store.journal.availableRewards.contains(item) ? "Ready to collect" : "\(item.requiredDays) recorded days")
                                        .font(.caption).foregroundStyle(Theme.secondaryInk)
                                }
                                Spacer(); Image(systemName: store.journal.roomRewards.contains(item) ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(Theme.accent)
                            }.card(padding: 14)
                        }.buttonStyle(.plain).accessibilityIdentifier("pet.room.\(item.rawValue)")
                    }
                    if let discoveries = store.journal.companionDiscoveries, !discoveries.isEmpty {
                        SectionLabel(title: "Little discoveries", subtitle: "Things \(store.companionName) has noticed with you.")
                        ForEach(PipStory.all) { item in
                            if let answer = discoveries[item.id], let choice = item.choices.first(where: { $0.id == answer }) {
                                Button { story = item } label: {
                                    HStack(spacing: 12) {
                                        AlongIcon(symbol: item.symbol, apricot: true)
                                        Text(choice.discovery).font(.subheadline.weight(.semibold))
                                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                                    }.card(padding: 14)
                                }.buttonStyle(.plain).accessibilityIdentifier("pet.discovery.\(item.id)")
                            }
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
                .sheet(item: $story) { PipStoryView(story: $0) }
                .sheet(item: $reward) { PipRewardView(reward: $0) }
        }
    }

    private func keepsake(_ accessory: Accessory, compact: Bool) -> some View {
        let available = store.journal.canUse(accessory)
        let selected = store.journal.accessory == accessory
        return Button {
            guard available else { previewAccessory = accessory; return }
            previewAccessory = nil
            if store.wearAccessory(accessory) { store.showToast("\(store.companionName)’s new look") }
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
                .background(selected ? Theme.softAccent : Theme.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain)
            .accessibilityIdentifier("companion.accessory.\(accessory.rawValue)")
            .accessibilityLabel("\(accessory.title), \(available ? (selected ? "selected" : "available") : "preview, unlocks after \(accessory.requiredDays) recorded days")")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
