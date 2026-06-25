import Foundation

/// Headless verification of the offline data pipeline: loads metadata, lazily
/// loads one line, and prints a sample departures board. Run with `--selftest`.
enum SelfTest {
    static func run() {
        do {
            let store = try DataStore()
            print("✓ metadata loaded")
            print("  railways:        \(store.railways.count)")
            print("  stations:        \(store.stations.count)")
            print("  directions:      \(store.directions.count)")
            print("  train types:     \(store.trainTypes.count)")
            print("  station groups:  \(store.stationGroups.count)")
            print("  through-svcs:    \(store.throughServices.count)")
            print("  timetable index: \(store.timetableIndex.count) railways")

            let repo = TimetableRepo(store: store)
            let service = DepartureService(store: store, repo: repo)

            let railway = "JR-East.Yamanote"
            let station = "JR-East.Yamanote.Shibuya"
            let direction = "OuterLoop"

            let entries = try repo.timetables(forRailway: railway) ?? []
            let cals = try repo.calendars(forRailway: railway)
            print("\n✓ lazy-loaded \(store.railwayTitle(railway)): \(entries.count) runs, calendars \(cals.sorted())")

            let now = Date()
            let deps = try service.upcoming(
                railwayId: railway, stationId: station, directionId: direction,
                now: now, limit: 5
            )

            let tf = DateFormatter()
            tf.timeZone = CalendarResolver.tokyo.timeZone
            tf.dateFormat = "HH:mm"
            let nowStr = tf.string(from: now)

            print("\n✓ next \(deps.count) departures — \(store.stationTitle(station)) → \(store.directionTitle(direction)) (now \(nowStr) JST):")
            if deps.isEmpty {
                print("  (none upcoming for today's calendar — likely run outside service hours)")
            }
            for d in deps {
                let mins = Int(d.expected.timeIntervalSince(now) / 60)
                let type = store.trainTypeTitle(d.trainTypeId) ?? ""
                let dest = d.destinationIds.map { store.stationTitle($0) }.joined(separator: "/")
                let name = d.trainName?.localized() ?? ""
                print("  \(tf.string(from: d.scheduled))  in \(mins)m  \(type) \(name) for \(dest)")
            }

            print("\n✓ self-test passed")
        } catch {
            print("✗ self-test FAILED: \(error)")
            exit(1)
        }
    }
}
