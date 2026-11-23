import Charts
import SwiftUI

/// Visualises public-catalogue reference bands for a peptide. Context only —
/// never dosing guidance or efficacy claims.
struct PeptideReferenceChart: View {
    var name: String
    var colour: PeptideColour
    private var reference: PeptideReference { Peptide.reference(for: name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reference profile").font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
            Text(PeptideReference.disclaimer)
                .font(.caption).foregroundStyle(SetupTheme.muted).fixedSize(horizontal: false, vertical: true)

            Chart(reference.points, id: \.label) { point in
                BarMark(
                    x: .value("Signal", point.value),
                    y: .value("Band", point.label)
                )
                .foregroundStyle(colour.tint)
                .cornerRadius(6)
            }
            .chartXScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let n = value.as(Int.self) {
                            Text("\(n)").font(.caption2).foregroundStyle(SetupTheme.muted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label).font(.caption.weight(.medium)).foregroundStyle(SetupTheme.ink)
                        }
                    }
                }
            }
            .frame(height: 132)
            .accessibilityIdentifier("peptide.reference")
        }
        .padding(16)
        .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
