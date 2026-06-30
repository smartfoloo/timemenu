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
            ).departures

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

            try realtimeChecks(repo: repo, service: service, railway: railway, station: station, direction: direction)

            print("\n✓ self-test passed")
        } catch {
            print("✗ self-test FAILED: \(error)")
            exit(1)
        }
    }

    /// Offline checks for the ODPT real-time overlay (no API key / network needed).
    private static func realtimeChecks(
        repo: TimetableRepo, service: DepartureService,
        railway: String, station: String, direction: String
    ) throws {
        // 1) ODPTTrain decodes the `odpt:`-prefixed JSON-LD shape.
        let sample = """
        [{"@id":"urn:x","odpt:railway":"odpt.Railway:JR-East.Yamanote",
          "odpt:trainNumber":"400G","odpt:delay":120,
          "odpt:railDirection":"odpt.RailDirection:JR-East.OuterLoop"}]
        """
        let trains = try JSONDecoder().decode([ODPTTrain].self, from: Data(sample.utf8))
        guard trains.first?.trainNumber == "400G", trains.first?.delaySeconds == 120 else {
            throw SelfTestError.assertion("ODPTTrain decode mismatch: \(trains)")
        }
        print("\n✓ ODPTTrain decodes (trainNumber=400G, delay=120s)")

        // 1b) ODPTTrainInformation decodes the line-status shape.
        let infoSample = """
        [{"@id":"urn:x","odpt:railway":"odpt.Railway:JR-East.Yamanote",
          "odpt:trainInformationText":{"en":"Normal service","ja":"平常運行"}}]
        """
        let infos = try JSONDecoder().decode([ODPTTrainInformation].self, from: Data(infoSample.utf8))
        let ls = LineStatus(text: infos.first?.text ?? [:], statusLabel: infos.first?.status)
        guard ls.isNormal, ls.display("ja") == "平常運行" else {
            throw SelfTestError.assertion("TrainInformation decode/status mismatch: \(infos)")
        }
        print("✓ ODPTTrainInformation decodes (normal, ja=平常運行)")

        // 2) A delay for a real train number flows through to its departure.
        let entries = try repo.timetables(forRailway: railway) ?? []
        let cal = CalendarResolver.calendarKey(
            available: try repo.calendars(forRailway: railway), for: Date()) ?? ""
        guard let target = entries.first(where: { e in
            e.calendar == cal && e.d == direction && e.n != nil
                && e.tt.contains { $0.s == station && $0.d != nil }
        }), let number = target.n,
              let depStr = target.tt.first(where: { $0.s == station })?.d,
              let offset = DepartureService.minutesSinceMidnight(depStr) else {
            throw SelfTestError.assertion("no suitable timetable entry to test delay")
        }
        // Pin "now" to 10 min before this train's departure so it's upcoming.
        let dayStart = CalendarResolver.tokyo.startOfDay(for: Date())
        let now = dayStart.addingTimeInterval(TimeInterval(offset * 60 - 600))
        let withDelay = try service.upcoming(
            railwayId: railway, stationId: station, directionId: direction,
            now: now, limit: 50, delaysByTrainNumber: [number: 300]
        ).departures
        guard let hit = withDelay.first(where: { $0.id == target.id }) else {
            throw SelfTestError.assertion("delayed train \(number) not found in upcoming")
        }
        guard hit.delayMinutes == 5,
              abs(hit.expected.timeIntervalSince(hit.scheduled) - 300) < 1 else {
            throw SelfTestError.assertion("delay not applied: \(String(describing: hit.delayMinutes))m")
        }
        print("✓ delay overlay applied (train \(number): +300s → +\(hit.delayMinutes!)m, expected = scheduled+5m)")

        // 3) Midnight boundary: at 23:51 we should still see trains after midnight.
        let tokyo = CalendarResolver.tokyo
        guard let lateNow = tokyo.date(bySettingHour: 23, minute: 51, second: 0, of: Date()) else {
            throw SelfTestError.assertion("could not build late-night time")
        }
        let late = try service.upcoming(
            railwayId: railway, stationId: station, directionId: direction, now: lateNow, limit: 3
        ).departures
        guard late.count == 3 else {
            throw SelfTestError.assertion("midnight: expected 3 departures at 23:51, got \(late.count)")
        }
        let crosses = late.contains {
            tokyo.component(.day, from: $0.scheduled) != tokyo.component(.day, from: lateNow)
        }
        guard crosses else {
            throw SelfTestError.assertion("midnight: no post-midnight train returned")
        }
        let tf = DateFormatter(); tf.timeZone = tokyo.timeZone; tf.dateFormat = "HH:mm"
        print("✓ midnight boundary at 23:51: \(late.map { tf.string(from: $0.scheduled) }.joined(separator: ", ")) (crosses midnight)")
    }

    enum SelfTestError: Error { case assertion(String) }
}
