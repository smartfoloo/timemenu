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
    /// - Parameter delaysByTrainNumber: live ODPT delays in seconds, keyed by
    ///   train number (`n`). Empty = schedule-only.
    func upcoming(
        railwayId: String,
        stationId: String,
        directionId: String,
        now: Date = Date(),
        limit: Int = 5,
        delaysByTrainNumber: [String: Int] = [:]
    ) throws -> [Departure] {
        guard let entries = try repo.timetables(forRailway: railwayId) else { return [] }
        let available = try repo.calendars(forRailway: railwayId)
        let cal = CalendarResolver.tokyo
        let grace: TimeInterval = -60  // keep a train that just departed within the last minute

        // Late-night trains may be stored as 24:xx on the current service day OR as
        // 00:xx on the next calendar day, depending on the operator — and in the
        // small hours the running trains belong to yesterday's service day. So
        // evaluate yesterday/today/tomorrow, each against its own midnight, and
        // de-duplicate the same run (it can appear in more than one window).
        var candidates: [Departure] = []
        for dayOffset in -1...1 {
            guard let dayDate = cal.date(byAdding: .day, value: dayOffset, to: now),
                  let calendarKey = CalendarResolver.calendarKey(available: available, for: dayDate)
            else { continue }
            let dayStart = cal.startOfDay(for: dayDate)

            for e in entries where e.calendar == calendarKey && e.d == directionId {
                guard let stop = e.tt.first(where: { $0.s == stationId }),
                      let timeString = stop.d,                   // departures board: needs a departure time
                      let offset = Self.minutesSinceMidnight(timeString)
                else { continue }

                let scheduled = dayStart.addingTimeInterval(TimeInterval(offset * 60))
                // Loop lines (e.g. Yamanote) carry no `ds`; fall back to the final stop.
                let destinations = e.ds ?? e.tt.last.map { [$0.s] } ?? []

                var dep = Departure(
                    id: e.id,
                    scheduled: scheduled,
                    directionId: e.d,
                    trainTypeId: e.y,
                    destinationIds: destinations,
                    trainName: e.nm?.first
                )
                if let n = e.n, let seconds = delaysByTrainNumber[n] {
                    dep.delayMinutes = Int((Double(seconds) / 60).rounded())
                }

                // Filter on expected time so a delayed train stays on the board.
                if dep.expected.timeIntervalSince(now) >= grace {
                    candidates.append(dep)
                }
            }
        }

        candidates.sort { $0.expected < $1.expected }

        // Keep each run once (its nearest upcoming occurrence), up to `limit`.
        var seen = Set<String>()
        var result: [Departure] = []
        for dep in candidates {
            guard seen.insert(dep.id).inserted else { continue }
            result.append(dep)
            if result.count == limit { break }
        }
        return result
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
