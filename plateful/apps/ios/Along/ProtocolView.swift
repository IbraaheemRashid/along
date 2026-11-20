import SwiftUI

/// The person's protocol: every tracked peptide and its schedule.
struct ProtocolView: View {
    @Environment(JournalStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Protocol").font(.system(size: 30, weight: .bold)).tracking(-0.6).foregroundStyle(SetupTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    PreviewBadge()
                }.padding(.top, 8)
                ForEach(store.journal.protocolPeptides) { peptide in
                    PeptideCard(peptide: peptide)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .appBackground()
    }
}

struct PeptideCard: View {
    var peptide: TrackedPeptide
    var body: some View {
        AppCard {
            HStack(spacing: 14) {
                PeptideBadge(name: peptide.name, dimmed: peptide.isPaused)
                VStack(alignment: .leading, spacing: 3) {
                    Text(peptide.name).font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                    Text([peptide.amountText ?? "Dose not set", peptide.schedule.summary].joined(separator: " · "))
                        .font(.footnote).foregroundStyle(SetupTheme.muted)
                    Text(peptide.isPaused ? "Paused" : peptide.schedule.timesSummary).font(.footnote).foregroundStyle(SetupTheme.muted)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("protocol.peptide.\(peptide.name)")
    }
}
