import Foundation

/// Body regions offered by the 3D injection-site picker. Tracking only — the
/// app never ranks or recommends a region, side or spot.
enum BodyRegion: String, Codable, CaseIterable, Identifiable {
    case abdomen, ventroglute, dorsoglute, flank, tricep, delt, thigh
    var id: String { rawValue }

    var title: String {
        switch self {
        case .abdomen: "Abdomen"
        case .ventroglute: "Ventroglute"
        case .dorsoglute: "Dorsoglute"
        case .flank: "Love handles"
        case .tricep: "Triceps"
        case .delt: "Delts"
        case .thigh: "Outer thigh"
        }
    }

    /// Lowercase name used in compact labels ("L ventroglute #2").
    var shortName: String {
        switch self {
        case .abdomen: "abdomen"
        case .ventroglute: "ventroglute"
        case .dorsoglute: "dorsoglute"
        case .flank: "love handle"
        case .tricep: "tricep"
        case .delt: "delt"
        case .thigh: "thigh"
        }
    }

    /// The abdomen is one area split into four quadrants; every other region
    /// is chosen per side.
    var isSided: Bool { self != .abdomen }

    /// Spots shown per side (per quadrant for the abdomen). Must match
    /// tools/body-model/export_asset.py.
    var spotCount: Int {
        switch self {
        case .abdomen: 4
        case .ventroglute: 3
        case .dorsoglute: 4
        case .flank: 3
        case .tricep: 2
        case .delt: 2
        case .thigh: 4
        }
    }
}

/// Always from the person's own perspective: their left, not the viewer's.
enum BodySide: String, Codable, CaseIterable, Identifiable {
    case left, right
    var id: String { rawValue }
    var title: String { self == .left ? "Left" : "Right" }
    var letter: String { self == .left ? "L" : "R" }
}

enum AbdomenQuadrant: String, Codable, CaseIterable, Identifiable {
    case upper, lower
    var id: String { rawValue }
    var title: String { self == .upper ? "Upper" : "Lower" }
}

/// One exact spot, e.g. `abdomen.left.lower.3` or `ventroglute.right.2`.
/// Stored on `DoseLog.spot` as its string id.
struct InjectionSpot: Hashable, Identifiable, Comparable {
    var region: BodyRegion
    var side: BodySide
    var quadrant: AbdomenQuadrant?
    var index: Int

    init?(region: BodyRegion, side: BodySide, quadrant: AbdomenQuadrant? = nil, index: Int) {
        guard (region == .abdomen) == (quadrant != nil), (1...region.spotCount).contains(index) else { return nil }
        self.region = region; self.side = side; self.quadrant = quadrant; self.index = index
    }

    init?(id: String) {
        let parts = id.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard let region = BodyRegion(rawValue: parts.first ?? ""), parts.count == (region == .abdomen ? 4 : 3),
              let side = BodySide(rawValue: parts[1]), let index = Int(parts[parts.count - 1]),
              String(index) == parts[parts.count - 1] else { return nil }
        let quadrant = region == .abdomen ? AbdomenQuadrant(rawValue: parts[2]) : nil
        if region == .abdomen && quadrant == nil { return nil }
        self.init(region: region, side: side, quadrant: quadrant, index: index)
    }

    var id: String {
        [region.rawValue, side.rawValue, quadrant?.rawValue, String(index)].compactMap { $0 }.joined(separator: ".")
    }

    /// The picker area this spot belongs to: `abdomen` or `<region>.<side>`.
    var areaID: String { region.isSided ? "\(region.rawValue).\(side.rawValue)" : region.rawValue }

    /// "Lower left", "Upper right" — abdomen only.
    var quadrantTitle: String? {
        quadrant.map { "\($0.title) \(side.rawValue)" }
    }

    /// "Abdomen · Lower left · Spot 3", "Ventroglute · Left · Spot 2".
    var title: String {
        "\(region.title) · \(quadrantTitle ?? side.title) · Spot \(index)"
    }

    /// Compact label for lists: "L abdomen, lower #3", "R ventroglute #2".
    var shortTitle: String {
        let base = "\(side.letter) \(region.shortName)"
        if let quadrant { return "\(base), \(quadrant.rawValue) #\(index)" }
        return "\(base) #\(index)"
    }

    /// Nearest of the original eight sites, so older views, exports and heat
    /// maps keep working for logs that carry an exact spot.
    var legacySite: InjectionSite {
        switch (region, side) {
        case (.abdomen, .left), (.flank, .left): .abdomenLeft
        case (.abdomen, .right), (.flank, .right): .abdomenRight
        case (.thigh, .left): .thighLeft
        case (.thigh, .right): .thighRight
        case (.delt, .left), (.tricep, .left): .armLeft
        case (.delt, .right), (.tricep, .right): .armRight
        case (.ventroglute, .left), (.dorsoglute, .left): .gluteLeft
        case (.ventroglute, .right), (.dorsoglute, .right): .gluteRight
        }
    }

    /// Every spot the picker can show, in a stable order.
    static let all: [InjectionSpot] = BodyRegion.allCases.flatMap { region -> [InjectionSpot] in
        let quadrants: [AbdomenQuadrant?] = region == .abdomen ? AbdomenQuadrant.allCases : [nil]
        return quadrants.flatMap { q in
            BodySide.allCases.flatMap { side in
                (1...region.spotCount).compactMap { InjectionSpot(region: region, side: side, quadrant: q, index: $0) }
            }
        }
    }

    static func < (lhs: InjectionSpot, rhs: InjectionSpot) -> Bool { lhs.id < rhs.id }
}

extension InjectionSpot: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let spot = InjectionSpot(id: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown injection spot \(raw)"))
        }
        self = spot
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(id)
    }
}

/// How often each exact spot appears in recent logs — tracking heat only.
struct SpotHeat: Equatable {
    var counts: [InjectionSpot: Int] = [:]
    var lastUsed: [InjectionSpot: Date] = [:]

    func count(for spot: InjectionSpot) -> Int { counts[spot] ?? 0 }

    /// Days since the spot was last logged, or nil if it hasn't been recently.
    func daysSinceUse(_ spot: InjectionSpot, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let date = lastUsed[spot] else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day
    }

    /// Plain-language history for the picker card. Describes the past; never advises.
    func historyText(for spot: InjectionSpot, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let days = daysSinceUse(spot, now: now, calendar: calendar) else { return "Not in your recent logs" }
        let when = days <= 0 ? "today" : days == 1 ? "yesterday" : "\(days) days ago"
        let n = count(for: spot)
        return "Last logged \(when) · \(n) recent \(n == 1 ? "log" : "logs")"
    }
}

extension ProtocolSchedule {
    /// The most recent exact spot logged for this peptide.
    static func lastSpot(for peptideID: UUID, logs: [DoseLog]) -> InjectionSpot? {
        logs.filter { $0.peptideID == peptideID && $0.status == .taken && $0.spot != nil }
            .max { $0.takenAt < $1.takenAt }?.spot
    }

    /// Relative use of exact spots, newest `limit` taken logs. Optional peptide filter.
    static func spotHeat(logs: [DoseLog], peptideID: UUID? = nil, limit: Int = 60) -> SpotHeat {
        let recent = logs
            .filter { $0.status == .taken && $0.spot != nil && (peptideID == nil || $0.peptideID == peptideID) }
            .sorted { $0.takenAt > $1.takenAt }
            .prefix(limit)
        var heat = SpotHeat()
        for log in recent {
            guard let spot = log.spot else { continue }
            heat.counts[spot, default: 0] += 1
            if heat.lastUsed[spot] == nil { heat.lastUsed[spot] = log.takenAt }
        }
        return heat
    }
}
