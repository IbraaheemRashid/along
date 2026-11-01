import SwiftUI

struct CompanionView: View {
    @Environment(JournalStore.self) private var store
    @State private var showNote = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DemoBadge()
                    VStack(alignment: .leading, spacing: 8) { Text("A little friend\nfor the everyday.").alongTitle(35); Text("Meet \(store.companionName). Curious, kind, and always happy to see you.").foregroundStyle(.secondary) }
                    MeadowView(accessory: store.journal.accessory).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 30))
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "quote.opening").font(.title2).foregroundStyle(Theme.peach)
                        VStack(alignment: .leading, spacing: 10) { Text("I collect little moments. A new path. A quiet morning. The days we just showed up.").font(.system(.title3, design: .serif)).lineSpacing(4); Text("— \(store.companionName)").font(.caption).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading).card()
                    SectionLabel(title: "A little more personality", subtitle: "Keepsakes appear as you record days. Once unlocked, they’re yours.")
                    ForEach(Accessory.allCases) { accessory in
                        let available = store.journal.canUse(accessory)
                        Button {
                            if available { store.journal.accessory = accessory; store.persist(); store.showToast("\(store.companionName)’s new look") }
                        } label: {
                            HStack(spacing: 16) {
                                PipView(accessory: accessory).frame(width: 64, height: 70).background(Theme.lilac.opacity(0.25), in: RoundedRectangle(cornerRadius: 17))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(accessory.title).font(.headline)
                                    Text(available ? "Yours to keep" : "Appears after \(accessory.requiredDays) recorded days").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: !available ? "lock" : store.journal.accessory == accessory ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Theme.accent)
                            }.card(padding: 14)
                        }.buttonStyle(.plain).disabled(!available).accessibilityLabel("\(accessory.title), \(available ? (store.journal.accessory == accessory ? "selected" : "available") : "unlocks after \(accessory.requiredDays) recorded days")")
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        Label("Always on your side", systemImage: "heart").font(.headline)
                        Text("\(store.companionName) never loses progress or gets upset when you’re away. There are no rewards for weight changes, eating less or taking medication.").font(.subheadline).foregroundStyle(.secondary)
                        Text("A fictional companion for reflection, not a person, clinician or emergency service.").font(.caption).foregroundStyle(.secondary)
                    }.card()
                }.padding(22).padding(.bottom, 20).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle(store.companionName).navigationBarTitleDisplayMode(.inline)
        }
    }
}
