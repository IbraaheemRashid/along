#if DEBUG
import Foundation

/// A fixed, fictional vial and syringe for the Dev Lab interaction study.
struct SyringeSample {
    enum MassUnit: String, CaseIterable {
        case mg, mcg
        var milligramsPerUnit: Decimal { self == .mg ? 1 : Decimal(1) / 1_000 }
    }

    enum Reading: Equatable {
        case empty, invalid, overCapacity
        case inRange(milligrams: Decimal, volume: Decimal, marks: Decimal)
    }

    static let vialMilligrams = Decimal(10)
    static let vialVolume = Decimal(2)
    static let unitsPerML = Decimal(100)
    static let capacity = 50
    static var concentration: Decimal { vialMilligrams / vialVolume }

    var amountText = ""
    var unit: MassUnit = .mg

    private var amount: Decimal? {
        let input = amountText.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !input.isEmpty, input.count <= 12,
              input.allSatisfy({ "0123456789.".contains($0) }),
              input.contains(where: { $0 != "." }),
              input.filter({ $0 == "." }).count <= 1 else { return nil }
        return Decimal(string: input, locale: Locale(identifier: "en_US_POSIX"))
    }

    var reading: Reading {
        if amountText.isEmpty { return .empty }
        guard let amount, amount >= 0 else { return .invalid }
        let milligrams = amount * unit.milligramsPerUnit
        let volume = milligrams / Self.concentration
        let marks = volume * Self.unitsPerML
        guard marks <= Decimal(Self.capacity) else { return .overCapacity }
        return .inRange(milligrams: milligrams, volume: volume, marks: marks)
    }

    mutating func changeUnit(to next: MassUnit) {
        guard next != unit else { return }
        if let amount {
            amountText = Self.text(amount * unit.milligramsPerUnit / next.milligramsPerUnit)
        }
        unit = next
    }

    mutating func move(to mark: Int) {
        let bounded = Decimal(min(Self.capacity, max(0, mark)))
        amountText = Self.text(bounded / Self.unitsPerML * Self.concentration / unit.milligramsPerUnit)
    }

    static func text(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
#endif
