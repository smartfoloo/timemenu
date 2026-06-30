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

/// Departures for a board, plus whether today's service is over. `serviceEnded`
/// is true only when the line runs today in this direction but every train has
/// already departed — distinct from a line that has no service today at all
/// (both yield an empty `departures`).
struct BoardDepartures {
    var departures: [Departure]
    var serviceEnded: Bool

    static let none = BoardDepartures(departures: [], serviceEnded: false)
}

/// Computes upcoming departures for a (railway, station, direction) board from
/// the static timetables.
final class DepartureService {
    /// Hour (Tokyo time) that splits one service day from the next. It sits in
    /// the nightly gap between the last post-midnight trains (~01:xx) and the
    /// first morning trains (~04:00), so "today's service" keeps trains that run
    /// just past midnight but excludes tomorrow's first departures.
    static let serviceDayStartHour = 3

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
    ) throws -> BoardDepartures {
        guard let entries = try repo.timetables(forRailway: railwayId) else { return .none }
        let available = try repo.calendars(forRailway: railwayId)
        let cal = CalendarResolver.tokyo
        let grace: TimeInterval = -60  // keep a train that just departed within the last minute

        // Bounds of the current service day in real Tokyo time. In the small
        // hours we're still in yesterday's service day, so anchor to the most
        // recent service-day boundary at or before `now`.
        let boundary = cal.date(bySettingHour: Self.serviceDayStartHour, minute: 0, second: 0, of: now) ?? now
        let serviceStart = now >= boundary ? boundary : cal.date(byAdding: .day, value: -1, to: boundary)!
        let serviceEnd = cal.date(byAdding: .day, value: 1, to: serviceStart)!

        // Late-night trains may be stored as 24:xx on the current service day OR as
        // 00:xx on the next calendar day, depending on the operator. So evaluate
        // yesterday/today/tomorrow, each against its own midnight, then keep only
        // departures whose real time lands inside today's service window — this
        // drops tomorrow's first trains. De-duplicate the same run (it can appear
        // in more than one window).
        var windowed: [Departure] = []
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
                // Only this service day's trains; tomorrow's are excluded.
                guard scheduled >= serviceStart, scheduled < serviceEnd else { continue }
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
                windowed.append(dep)
            }
        }

        windowed.sort { $0.expected < $1.expected }

        // Keep each run once (its nearest occurrence in the window). `runs` covers
        // the whole service day, including trains that have already left.
        var seen = Set<String>()
        let runs = windowed.filter { seen.insert($0.id).inserted }

        // Trains still to come (a recently-departed one is kept via `grace`),
        // capped at `limit` — fewer than `limit` simply shows fewer.
        let result = Array(runs.filter { $0.expected.timeIntervalSince(now) >= grace }.prefix(limit))

        // Nothing left but the line did run today this way ⇒ service is over.
        return BoardDepartures(departures: result, serviceEnded: result.isEmpty && !runs.isEmpty)
    }

    /// Destinations that characterize travel from `stationId` heading `directionId`:
    /// the line's own terminus in that direction, followed by the most frequent
    /// through-service destinations beyond the line. For a Toyoko Shibuya outbound
    /// board this yields [Yokohama, Motomachi-Chukagai] → "横浜・元町・中華街方面".
    ///
    /// Returns `[]` for loop lines (no single terminus to name) or when no timetable
    /// is available, so callers can fall back to the plain direction name.
    func directionDestinations(
        railwayId: String,
        stationId: String,
        directionId: String,
        maxThrough: Int = 1
    ) -> [String] {
        guard let railway = store.railwaysById[railwayId],
              let entries = try? repo.timetables(forRailway: railwayId),
              let first = railway.stations.first,
              let last = railway.stations.last,
              first != last                       // loop line: no single terminus
        else { return [] }

        // `ascending` runs toward the end of the station list, `descending` toward
        // the start; that end station is the canonical terminus for the direction.
        let terminus: String?
        switch directionId {
        case railway.ascending: terminus = last
        case railway.descending: terminus = first
        default: terminus = nil                   // loop directions, etc.
        }
        guard let terminus, terminus != stationId else { return [] }

        // Tally destinations of trains that actually depart this station this way,
        // keeping only those beyond the line (through-services) — the on-line
        // terminus is named explicitly below regardless of how few trains end there.
        let onLine = Set(railway.stations)
        var throughCounts: [String: Int] = [:]
        for e in entries where e.d == directionId {
            guard e.tt.contains(where: { $0.s == stationId && $0.d != nil }) else { continue }
            let dests = e.ds ?? e.tt.last.map { [$0.s] } ?? []
            for d in dests where !onLine.contains(d) { throughCounts[d, default: 0] += 1 }
        }

        let through = throughCounts.sorted { $0.value > $1.value }.prefix(maxThrough).map(\.key)
        return [terminus] + through
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
