import SwiftUI

/// Peptide list lives under Settings now that the former Protocol tab is Health.
struct ProtocolPeptidesView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editor: PeptideEditor.Mode?

    private var active: [TrackedPeptide] { store.journal.activePeptides }
    private var paused: [TrackedPeptide] { store.journal.protocolPeptides.filter(\.isPaused) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.journal.protocolPeptides.isEmpty {
                        empty
                    } else {
                        if !active.isEmpty {
                            AppSectionTitle(title: "Active", trailing: "\(active.count)")
                            ForEach(active) { peptide in PeptideCard(peptide: peptide) { editor = .edit(peptide) } }
                        }
                        if !paused.isEmpty {
                            AppSectionTitle(title: "Paused", trailing: "\(paused.count)")
                            ForEach(paused) { peptide in PeptideCard(peptide: peptide) { editor = .edit(peptide) } }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
            .background(SetupTheme.tile.ignoresSafeArea())
            .navigationTitle("Your peptides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .overlay(alignment: .bottomTrailing) {
                if store.journal.protocolPeptides.count < TrackedPeptide.limit {
                    Button { editor = .add } label: {
                        Image(systemName: "plus").font(.system(size: 22, weight: .semibold)).foregroundStyle(SetupTheme.inverseInk)
                            .frame(width: 58, height: 58).background(SetupTheme.ink, in: Circle())
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    }
                    .buttonStyle(SetupPressStyle())
                    .accessibilityLabel("Add a peptide").accessibilityIdentifier("protocol.add")
                    .padding(.trailing, 20).padding(.bottom, 16)
                }
            }
            .sheet(item: $editor) { PeptideEditor(mode: $0) }
        }
    }

    private var empty: some View {
        AppCard(padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Build your protocol").font(.headline).foregroundStyle(SetupTheme.ink)
                Text("Add each peptide with the schedule you follow. Amounts stay blank until you enter them.")
                    .font(.subheadline).foregroundStyle(SetupTheme.muted).fixedSize(horizontal: false, vertical: true)
                SetupPrimaryButton(title: "Add a peptide", symbol: "plus", identifier: "protocol.empty-add") { editor = .add }
            }
        }
    }
}

struct PeptideCard: View {
    var peptide: TrackedPeptide
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                PeptideBadge(name: peptide.name, color: peptide.displayColor, dimmed: peptide.isPaused)
                VStack(alignment: .leading, spacing: 3) {
                    Text(peptide.name).font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                    Text([peptide.amountText ?? "Dose not set", peptide.schedule.summary].joined(separator: " · "))
                        .font(.footnote).foregroundStyle(SetupTheme.muted)
                    Text(peptide.isPaused ? "Paused" : peptide.schedule.timesSummary)
                        .font(.footnote).foregroundStyle(SetupTheme.muted)
                    if let expiry = peptide.batchExpirySummary {
                        Text(expiry).font(.footnote.weight(.medium)).foregroundStyle(SetupTheme.ink.opacity(0.7))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(SetupTheme.muted)
            }
            .padding(18)
            .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(SetupPressStyle())
        .accessibilityIdentifier("protocol.peptide.\(peptide.name)")
    }
}
