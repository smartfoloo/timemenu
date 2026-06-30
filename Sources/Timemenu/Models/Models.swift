import Foundation

/// A multilingual title dictionary, keyed by language code ("en", "ja", ...).
typealias Localized = [String: String]

extension Dictionary where Key == String, Value == String {
    /// Resolve a display string for the requested language, falling back through
    /// English, Japanese, then any available value.
    func localized(_ language: String = "en") -> String {
        self[language] ?? self["en"] ?? self["ja"] ?? first?.value ?? ""
    }
}

// MARK: - Metadata (small lookup tables, loaded once at launch)

/// A rail line. `stations` is the ordered list of station ids along the line;
/// `ascending`/`descending` reference RailDirection ids.
struct Railway: Codable, Identifiable, Hashable {
    let id: String
    let title: Localized
    let stations: [String]
    let ascending: String?
    let descending: String?
    let color: String?
    let carComposition: Int?
}

struct Station: Codable, Identifiable, Hashable {
    let id: String
    let railway: String?
    let coord: [Double]?
    let title: Localized
}

struct RailDirection: Codable, Identifiable, Hashable {
    let id: String
    let title: Localized
}

struct TrainType: Codable, Identifiable, Hashable {
    let id: String
    let title: Localized
}

struct TrainVehicle: Codable, Identifiable, Hashable {
    let id: String
    /// Normalized to an array; the source has `color` as either a string or an array.
    let color: [String]

    enum CodingKeys: String, CodingKey { case id, color }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        if let single = try? c.decode(String.self, forKey: .color) {
            color = [single]
        } else {
            color = (try? c.decode([String].self, forKey: .color)) ?? []
        }
    }
}

// MARK: - Timetables (one array per line, loaded lazily)

/// A scheduled train run on a given calendar (the calendar is the suffix of `id`,
/// e.g. ".Weekday"). Field names mirror the compact source JSON.
struct TrainTimetable: Codable, Identifiable {
    let id: String
    let t: String?            // train id
    let r: String             // railway id
    let n: String?            // train number
    let y: String?            // train type id
    let d: String?            // rail direction id
    let os: [String]?         // origin station ids
    let ds: [String]?         // destination station ids
    let nm: [Localized]?      // named train(s), e.g. "Odoriko 1"
    let v: String?            // vehicle id
    let pt: [String]?         // previous train timetable ids (through-service)
    let nt: [String]?         // next train timetable ids (through-service)
    let tt: [TimetableStop]   // ordered stops

    /// The calendar key, e.g. "Weekday", "SaturdayHoliday", "Holiday".
    var calendar: String {
        String(id.split(separator: ".").last ?? "")
    }
}

/// A single stop. Times are "HH:mm" and may use the service-day convention where
/// the hour can reach 24 (i.e. past midnight, still the same service day).
struct TimetableStop: Codable, Hashable {
    let s: String     // station id
    let d: String?    // departure time
    let a: String?    // arrival time
}
