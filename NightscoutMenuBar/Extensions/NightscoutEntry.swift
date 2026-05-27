//
//  NightscoutEntry.swift
//  NightscoutMenuBar
//
//  Blood glucose entry model parsed from the Nightscout REST API (/api/v1/entries.json).
//

import Cocoa

enum BloodGlucoseTrend: Int, Decodable {
    case none = 0
    case tripleUp = 1
    case doubleUp = 2
    case singleUp = 3
    case fortyFiveUp = 4
    case flat = 5
    case fortyFiveDown = 6
    case singleDown = 7
    case doubleDown = 8
    case tripleDown = 9
    case notComputable = 10
    case rateOutOfRange = 11

    // Nightscout also returns trend as a direction string
    init?(direction: String) {
        switch direction {
        case "TripleUp":        self = .tripleUp
        case "DoubleUp":        self = .doubleUp
        case "SingleUp":        self = .singleUp
        case "FortyFiveUp":     self = .fortyFiveUp
        case "Flat":            self = .flat
        case "FortyFiveDown":   self = .fortyFiveDown
        case "SingleDown":      self = .singleDown
        case "DoubleDown":      self = .doubleDown
        case "TripleDown":      self = .tripleDown
        case "NONE":            self = .none
        case "NOT COMPUTABLE":  self = .notComputable
        case "RATE OUT OF RANGE": self = .rateOutOfRange
        default:                return nil
        }
    }

    var symbol: String {
        switch self {
        case .tripleUp:         return "⬆︎⬆︎⬆︎"
        case .doubleUp:         return "⬆︎⬆︎"
        case .singleUp:         return "⬆︎"
        case .fortyFiveUp:      return "↗︎"
        case .flat:             return "→"
        case .fortyFiveDown:    return "↘︎"
        case .singleDown:       return "⬇︎"
        case .doubleDown:       return "⬇︎⬇︎"
        case .tripleDown:       return "⬇︎⬇︎⬇︎"
        default:                return ""
        }
    }
}

struct NightscoutEntry: Decodable {
    var sgv: Double?
    var date: Date
    var trend: BloodGlucoseTrend?
    var delta: Double?

    private enum CodingKeys: String, CodingKey {
        case sgv, trend, delta, date, direction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sgv   = try c.decodeIfPresent(Double.self, forKey: .sgv)
        delta = try c.decodeIfPresent(Double.self, forKey: .delta)

        // Prefer numeric trend, fall back to direction string
        if let raw = try c.decodeIfPresent(Int.self, forKey: .trend) {
            trend = BloodGlucoseTrend(rawValue: raw)
        } else if let dir = try c.decodeIfPresent(String.self, forKey: .direction) {
            trend = BloodGlucoseTrend(direction: dir)
        } else {
            trend = nil
        }

        // Nightscout `date` is milliseconds since epoch
        let ms = try c.decode(Double.self, forKey: .date)
        date = Date(timeIntervalSince1970: ms / 1000)
    }
}

extension NightscoutEntry {
    init(copying other: NightscoutEntry, delta: Double?) {
        self.sgv = other.sgv
        self.date = other.date
        self.trend = other.trend
        self.delta = delta
    }
}

extension NightscoutEntry {
    var glucoseValueString: String {
        guard let value = sgv else { return "?" }
        return String(Int(value))
    }

    var menuBarColor: NSColor {
        guard let value = sgv else { return .labelColor }
        switch value {
        case ..<55:     return .systemRed
        case 55..<70:   return .systemOrange
        case 70..<180:  return .systemGreen
        case 180..<250: return .systemYellow
        default:        return .systemRed
        }
    }

    func menuBarAttributedString(delta: Double?, includingDelta: Bool, includingTimeAgo: Bool) -> NSAttributedString {
        var text = glucoseValueString
        if includingDelta, let d = delta {
            let sign = d >= 0 ? "+" : ""
            text += " (\(sign)\(Int(d)))"
        }
        if let trend { text += " \(trend.symbol)" }
        if includingTimeAgo {
            let mins = Int(Date().timeIntervalSince(date) / 60)
            let fmt = NSLocalizedString("(%d min ago)", comment: "Minutes since reading")
            text += " \(String(format: fmt, mins))"
        }
        return NSAttributedString(string: text, attributes: [.foregroundColor: menuBarColor])
    }

    func menuItemString(delta: Double?, includingDelta: Bool) -> String {
        var text = glucoseValueString
        if includingDelta, let d = delta {
            let sign = d >= 0 ? "+" : ""
            text += " (\(sign)\(Int(d)))"
        }
        if let trend { text += " \(trend.symbol)" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        let fmt = NSLocalizedString("(%d min ago)", comment: "Minutes since reading")
        text += " \(String(format: fmt, mins))"
        return text
    }
}
