import SwiftUI

struct PipProgressCard: View {
    @Environment(JournalStore.self) private var store
    @State private var reward: PipReward?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AlongIcon(symbol: "sparkles", apricot: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Growing together").font(.system(.headline, design: .rounded))
                    Text("\(store.journal.recordedDayCount) recorded \(store.journal.recordedDayCount == 1 ? "day" : "days")")
                        .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        .accessibilityIdentifier("pet.progress.count")
                }
                Spacer(minLength: 0)
            }
            if let earned = store.journal.availableRewards.first {
                Button { reward = earned } label: {
                    HStack {
                        Image(systemName: "gift.fill")
                        Text("A keepsake is ready").font(.subheadline.weight(.semibold))
                        Spacer(); Image(systemName: "arrow.right")
                    }.frame(minHeight: 48).padding(.horizontal, 14)
                        .background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityIdentifier("pet.reward.ready")
            }
            if let next = store.journal.nextReward {
                ProgressView(value: Double(store.journal.recordedDayCount), total: Double(next.requiredDays))
                    .tint(Theme.accent).accessibilityLabel("Progress towards \(next.title)")
                    .accessibilityValue("\(store.journal.recordedDayCount) of \(next.requiredDays) recorded days")
                Text("Next: \(next.title) · \(next.requiredDays - store.journal.recordedDayCount) more \(next.requiredDays - store.journal.recordedDayCount == 1 ? "day" : "days")")
                    .font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
            } else {
                Text("Every keepsake is yours. There’s still room for your story to grow.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }
            Text("A check-in or a chosen routine counts once per day. Days don’t have to be in a row.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
        }.card(padding: 18).sheet(item: $reward) { PipRewardView(reward: $0) }
    }
}

struct PipRewardView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let reward: PipReward
    @State private var claimed = false
    private var isOwned: Bool { store.journal.roomRewards.contains(reward) }
    private var isReady: Bool { store.journal.availableRewards.contains(reward) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PipRoomView(accessory: reward.accessory ?? store.journal.accessory, pose: isReady || claimed ? .celebrate : .welcome,
                                height: 230, rewards: store.journal.roomRewards.union([reward]))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    Pill(text: isReady ? "A keepsake for your journey" : isOwned ? "Yours to keep" : "A little look ahead", symbol: isOwned || isReady ? "gift" : "eye")
                    Text(reward.title).alongTitle(30)
                    Text(reward.detail.replacingOccurrences(of: "Pip", with: store.companionName)).foregroundStyle(Theme.secondaryInk)
                    if isReady {
                        Text("\(reward.requiredDays) recorded \(reward.requiredDays == 1 ? "day" : "days"). Each one a little part of your story.").font(.subheadline)
                        PrimaryButton(title: reward.accessory == nil ? "Add to our room" : "Try it on", symbol: "checkmark") {
                            if store.claimReward(reward) { claimed = true }
                        }.accessibilityIdentifier("pet.reward.claim")
                    } else if isOwned {
                        if let accessory = reward.accessory {
                            PrimaryButton(title: store.journal.accessory == accessory ? "Wearing it" : "Wear this keepsake", symbol: "checkmark") {
                                if store.wearAccessory(accessory) { dismiss() }
                            }
                        } else { Label("At home in your room", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        PrimaryButton(title: "Back to my day") { dismiss() }
                    } else {
                        Text("Yours after \(reward.requiredDays) recorded days. You have \(store.journal.recordedDayCount) so far.").font(.subheadline)
                        Text("This is a preview. Take your time; there’s no deadline.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }.padding(22).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("A little keepsake").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
                .sensoryFeedback(.success, trigger: claimed)
        }
    }
}
