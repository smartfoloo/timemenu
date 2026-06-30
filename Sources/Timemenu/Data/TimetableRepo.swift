import Foundation

/// Lazily loads and caches per-line timetables. Each line's JSON is decompressed
/// from the bundle on first use and kept in memory for subsequent queries.
final class TimetableRepo {
    static let subdir = "Data/timetables"

    private let store: DataStore
    private var cache: [String: [TrainTimetable]] = [:]          // stem -> entries
    private var calendarsCache: [String: Set<String>] = [:]      // stem -> calendar keys

    init(store: DataStore) {
        self.store = store
    }

    /// All timetable entries for a railway line, loading from the bundle on first
    /// access. Returns nil if the railway has no indexed timetable file.
    func timetables(forRailway railwayId: String) throws -> [TrainTimetable]? {
        guard let stem = store.timetableIndex[railwayId] else { return nil }
        if let cached = cache[stem] { return cached }
        let entries = try ResourceLoader.load(
            [TrainTimetable].self, name: stem, subdir: TimetableRepo.subdir
        )
        cache[stem] = entries
        calendarsCache[stem] = Set(entries.map(\.calendar))
        return entries
    }

    /// The set of calendar keys ("Weekday", "Holiday", ...) a line actually uses.
    func calendars(forRailway railwayId: String) throws -> Set<String> {
        guard let stem = store.timetableIndex[railwayId] else { return [] }
        if let cached = calendarsCache[stem] { return cached }
        _ = try timetables(forRailway: railwayId)
        return calendarsCache[stem] ?? []
    }
}
