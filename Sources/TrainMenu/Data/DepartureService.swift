import Foundation

/// A single upcoming departure, ready for display. `delayMinutes` is always nil
/// in v1 (schedule-derived); the Phase 5 ODPT overlay will populate it without
/// changing this shape or the UI.
struct Departure: Identifiable {
    let id: String              // timetable id
    let scheduled: Date
    let directionId: String?
    let trainTypeId: String?
    let destinationIds: [String]
    let trainName: Localized?
    var delayMinutes: Int? = nil

    /// Effective time including any known delay.
    var expected: Date {
        guard let delayMinutes else { return scheduled }
        return scheduled.addingTimeInterval(TimeInterval(delayMinutes * 60))
    }
}

/// Computes upcoming departures for a (railway, station, direction) board from
/// the static timetables.
final class DepartureService {
    private let store: DataStore
    private let repo: TimetableRepo

    init(store: DataStore, repo: TimetableRepo) {
        self.store = store
        self.repo = repo
    }

    /// Next departures from `stationId` on `railwayId` heading `directionId`,
    /// at or after `now`.
    func upcoming(
        railwayId: String,
        stationId: String,
        directionId: String,
        now: Date = Date(),
        limit: Int = 5
    ) throws -> [Departure] {
        guard let entries = try repo.timetables(forRailway: railwayId) else { return [] }
        let available = try repo.calendars(forRailway: railwayId)
        guard let calendar = CalendarResolver.calendarKey(available: available, for: now) else {
            return []
        }

        // Start of the service day in Tokyo time; "HH:mm" offsets are added to this.
        let dayStart = CalendarResolver.tokyo.startOfDay(for: now)
        let grace: TimeInterval = -60  // keep a train that just departed within the last minute

        var result: [Departure] = []
        for e in entries where e.calendar == calendar && e.d == directionId {
            guard let stop = e.tt.first(where: { $0.s == stationId }),
                  let timeString = stop.d,                       // departures board: needs a departure time
                  let offset = Self.minutesSinceMidnight(timeString)
            else { continue }

            let scheduled = dayStart.addingTimeInterval(TimeInterval(offset * 60))
            guard scheduled.timeIntervalSince(now) >= grace else { continue }

            // Loop lines (e.g. Yamanote) carry no `ds`; fall back to the final stop.
            let destinations = e.ds ?? e.tt.last.map { [$0.s] } ?? []

            result.append(Departure(
                id: e.id,
                scheduled: scheduled,
                directionId: e.d,
                trainTypeId: e.y,
                destinationIds: destinations,
                trainName: e.nm?.first
            ))
        }

        result.sort { $0.scheduled < $1.scheduled }
        return Array(result.prefix(limit))
    }

    /// Parse "HH:mm" into minutes since midnight. Hours may be >= 24 (service-day
    /// convention for trains running past midnight), which naturally rolls the
    /// computed Date into the next calendar day.
    static func minutesSinceMidnight(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
