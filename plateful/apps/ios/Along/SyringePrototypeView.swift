#if DEBUG
import SwiftUI

struct SyringePrototypeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sample = SyringeSample()
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppSectionTitle(title: "Sample vial")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("10 mg in 2 mL").font(.headline)
                        Text("Fictional vial · 5 mg/mL").font(.subheadline).foregroundStyle(SetupTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16).background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sample amount").font(.headline)
                        HStack {
                            TextField("Enter an amount", text: $sample.amountText)
                                .keyboardType(.decimalPad).focused($typing)
                                .font(.title3.monospacedDigit())
                                .accessibilityLabel("Sample amount").accessibilityIdentifier("syringe.amount")
                            Picker("Amount unit", selection: Binding(get: { sample.unit }, set: { sample.changeUnit(to: $0) })) {
                                ForEach(SyringeSample.MassUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 54)
                        .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("U-100 · 0.5 mL").font(.subheadline.weight(.semibold))
                        readout
                        SampleSyringeScale(marks: marks) { mark in
                            typing = false
                            sample.move(to: mark)
                        }
                        Text("Drag the plunger. Each mark is one unit.")
                            .font(.footnote).foregroundStyle(SetupTheme.muted)
                    }
                    .padding(16).background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(SetupTheme.border))
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Syringe prototype").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done typing") { typing = false } }
            }
        }
    }

    private var marks: Decimal? {
        if case .inRange(_, _, let value) = sample.reading { return value }
        return nil
    }

    @ViewBuilder private var readout: some View {
        switch sample.reading {
        case .empty:
            Text("Type an amount or drag the plunger.").font(.subheadline)
        case .invalid:
            Text("Enter one numeric amount.").font(.subheadline)
        case .overCapacity:
            Text("This amount exceeds the sample syringe’s 50-unit capacity.").font(.subheadline)
        case .inRange(let mg, let volume, let marks):
            let value = SyringeSample.text(marks)
            Text("\(value) units").font(.largeTitle.bold().monospacedDigit())
                .accessibilityIdentifier("syringe.readout")
            Text("\(SyringeSample.text(mg)) mg ÷ 5 mg/mL = \(SyringeSample.text(volume)) mL")
            Text("\(SyringeSample.text(volume)) mL × 100 units/mL = \(value) units")
                .font(.footnote).foregroundStyle(SetupTheme.muted)
            if marks != Decimal(NSDecimalNumber(decimal: marks).intValue) {
                Text("Between whole-unit marks.").font(.footnote.weight(.semibold))
            }
        }
    }
}

private struct SampleSyringeScale: View {
    let marks: Decimal?
    let move: (Int) -> Void
    private let inset: CGFloat = 24
    private let capacity = SyringeSample.capacity

    var body: some View {
        GeometryReader { geometry in
            let length = max(1, geometry.size.width - inset * 2)
            let barrel = CGRect(x: inset, y: 16, width: length, height: 34)
            Canvas { context, _ in
                let outline = Path(roundedRect: barrel, cornerRadius: 5)
                context.fill(outline, with: .color(SetupTheme.tile))
                var hardware = Path()
                hardware.move(to: CGPoint(x: 1, y: barrel.midY))
                hardware.addLine(to: CGPoint(x: inset, y: barrel.midY))
                context.stroke(hardware, with: .color(SetupTheme.muted), lineWidth: 3)
                if let marks {
                    let fraction = CGFloat(NSDecimalNumber(decimal: marks).doubleValue) / CGFloat(capacity)
                    let width = length * fraction
                    var fill = context
                    fill.clip(to: outline)
                    fill.fill(Path(CGRect(x: inset, y: barrel.minY, width: width, height: barrel.height)), with: .color(.blue.opacity(0.32)))
                    let x = inset + width
                    var rod = Path()
                    rod.move(to: CGPoint(x: x, y: barrel.midY))
                    rod.addLine(to: CGPoint(x: barrel.maxX + 15, y: barrel.midY))
                    context.stroke(rod, with: .color(SetupTheme.muted), lineWidth: 5)
                    context.fill(Path(roundedRect: CGRect(x: barrel.maxX + 13, y: barrel.midY - 12, width: 5, height: 24), cornerRadius: 2),
                                 with: .color(SetupTheme.ink))
                    fill.fill(Path(CGRect(x: x - 2, y: barrel.minY, width: 4, height: barrel.height)), with: .color(SetupTheme.ink))
                }
                context.stroke(outline, with: .color(SetupTheme.ink), lineWidth: 1.5)
                var ticks = Path()
                for mark in 0...capacity {
                    let x = inset + length * CGFloat(mark) / CGFloat(capacity)
                    let major = mark.isMultiple(of: 10)
                    let height: CGFloat = major ? 15 : (mark.isMultiple(of: 5) ? 10 : 6)
                    ticks.move(to: CGPoint(x: x, y: barrel.minY))
                    ticks.addLine(to: CGPoint(x: x, y: barrel.minY + height))
                    if major {
                        context.draw(Text("\(mark)").font(.caption2).foregroundColor(SetupTheme.ink),
                                     at: CGPoint(x: x, y: barrel.maxY + 14))
                    }
                }
                context.stroke(ticks, with: .color(SetupTheme.ink), lineWidth: 1)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let fraction = min(1, max(0, (drag.location.x - inset) / length))
                move(Int((fraction * CGFloat(capacity)).rounded()))
            })
        }
        .frame(height: 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample syringe plunger")
        .accessibilityValue(marks.map { "\(SyringeSample.text($0)) units" } ?? "No mark selected")
        .accessibilityIdentifier("syringe.plunger")
        .accessibilityAdjustableAction { direction in
            let value = marks.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
            switch direction {
            case .increment: move(Int(floor(value)) + 1)
            case .decrement: move(Int(ceil(value)) - 1)
            @unknown default: break
            }
        }
    }
}
#endif
