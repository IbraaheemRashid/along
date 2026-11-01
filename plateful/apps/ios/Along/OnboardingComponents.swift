import SwiftUI

struct SetupChoice: View {
    let title: String
    var detail: String? = nil
    var symbol: String = "sparkles"
    var selected = false
    var identifier = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(selected ? Theme.softAccent : Theme.softApricot, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(.body, design: .rounded, weight: .semibold))
                    if let detail { Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryInk).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(selected ? Theme.accent : Color.secondary.opacity(0.3))
            }
            .padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.softAccent : Theme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? Theme.accent.opacity(0.65) : Theme.line, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityElement(children: .combine)
    }
}

struct SetupNote: View {
    var text: String
    var symbol = "leaf"
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).padding(.top, 2)
            Text(text).font(.subheadline).foregroundStyle(Theme.secondaryInk).lineSpacing(3)
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.softApricot, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct SetupHero: View {
    var pose: PipPose = .welcome
    var accessory: Accessory = .leaf
    var height: CGFloat = 245
    var caption: String? = nil
    var body: some View {
        PipRoomView(accessory: accessory, pose: pose, message: caption, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .accessibilityHidden(true)
    }
}

struct SetupJournalCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    var draft: OnboardingDraft
    var recorded = false
    var entry: CheckIn? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "book.closed").font(.title3).foregroundStyle(Theme.accent)
                Text(recorded ? (entry == nil ? "EXAMPLE PAGE" : "YOUR FIRST PAGE") : "YOUR JOURNEY").font(.caption2.weight(.bold)).tracking(1.6).foregroundStyle(Theme.accent)
                Spacer()
                Image(systemName: "bookmark.fill").foregroundStyle(Theme.peach)
            }
            Text(draft.name.isEmpty ? "A beginning,\nin your own words." : "\(draft.name)’s\nnew chapter.").alongTitle(29)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Theme.line).frame(height: 1)
            if recorded, let mood = entry?.mood ?? draft.mood, let appetite = entry?.appetite ?? draft.appetite {
                Text(entry?.day.formatted(.dateTime.day().month(.abbreviated).year()).uppercased() ?? "EXAMPLE ENTRY").font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(Theme.secondaryInk)
                let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                layout { Pill(text: mood.shortTitle, symbol: mood.symbol); Pill(text: appetite.title, symbol: "leaf") }
                if !(entry?.note ?? draft.note).isEmpty { Text(entry?.note ?? draft.note).font(.system(.body, design: .serif)).lineSpacing(4) }
                else { Text("You made a little space to notice today.").font(.system(.body, design: .serif)).foregroundStyle(Theme.secondaryInk).lineSpacing(4) }
            } else {
                Text(draft.intention.isEmpty ? "The things you notice. The routines you choose. The moments that matter to you." : draft.intention)
                    .font(.system(.body, design: .serif)).lineSpacing(5).foregroundStyle(Theme.secondaryInk)
                if !draft.progressAreas.isEmpty {
                    Text(draft.progressAreas.sorted().joined(separator: "  ·  ")).font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
                }
            }
            HStack {
                Circle().fill(Theme.peach).frame(width: 7, height: 7)
                Text(recorded ? (entry == nil ? "Example only · not a saved entry" : "Saved on this device") : "Made around what matters to you").font(.caption).foregroundStyle(Theme.secondaryInk)
            }
        }.padding(25).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(Theme.peach.opacity(0.75)).frame(width: 4).padding(.vertical, 24).padding(.leading, 10) }
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line))
            .shadow(color: Theme.ink.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

struct SetupBenefit: View {
    var number: String
    var title: String
    var detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number).font(.system(.title3, design: .serif)).foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42).background(Theme.lilac.opacity(0.35), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryInk).lineSpacing(3)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).card(padding: 16)
    }
}

struct MembershipPlans: View {
    @Environment(BillingStore.self) private var billing
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Binding var selection: OnboardingPlan
    var body: some View {
        VStack(spacing: 10) {
            plan(.annual, title: "Yearly", price: billing.product(for: .annual)?.displayPrice ?? "—", period: "/ year", detail: "One payment each year", badge: nil)
            plan(.monthly, title: "Monthly", price: billing.product(for: .monthly)?.displayPrice ?? "—", period: "/ month", detail: "One payment each month", badge: nil)
        }
    }
    private func plan(_ plan: OnboardingPlan, title: String, price: String, period: String, detail: String, badge: String?) -> some View {
        Button { selection = plan } label: {
            VStack(alignment: .leading, spacing: 8) {
                let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 9))
                layout {
                    HStack(spacing: 9) {
                        Image(systemName: selection == plan ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Theme.accent)
                        Text(title).font(.headline)
                        if let badge { Text(badge).font(.system(size: 8, weight: .bold)).tracking(0.5).padding(.horizontal, 7).padding(.vertical, 5).background(Theme.softApricot, in: Capsule()) }
                    }
                    if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(price).font(.title3.weight(.semibold))
                        Text(period).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }
                Text(detail).font(.caption).foregroundStyle(Theme.secondaryInk).padding(.leading, 30)
            }.padding(17).background(selection == plan ? Theme.softAccent : Theme.card, in: RoundedRectangle(cornerRadius: 19))
                .overlay(RoundedRectangle(cornerRadius: 19).stroke(selection == plan ? Theme.accent : Theme.line, lineWidth: selection == plan ? 2 : 1))
        }.buttonStyle(.plain).accessibilityIdentifier("onboarding.plan.\(plan.rawValue)")
            .accessibilityAddTraits(selection == plan ? .isSelected : [])
    }
}

struct MembershipDisclosure: View {
    @Environment(BillingStore.self) private var billing
    var plan: OnboardingPlan
    var body: some View {
        Text(billing.product(for: plan.billingPlan).map { "\($0.displayPrice) charged when you subscribe, then every \($0.plan.periodLabel) until cancelled. No free trial. Manage or cancel in your App Store subscription settings." } ?? "App Store prices appear when plans are available. No free trial. Payment begins when you subscribe and renews until cancelled.")
            .font(.caption).foregroundStyle(Theme.secondaryInk).multilineTextAlignment(.center).lineSpacing(3)
    }
}
