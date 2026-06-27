import Foundation

/// CLI helper to verify a live ODPT key/endpoint without launching the GUI:
///   ODPT_API_KEY=yourkey swift run TrainMenu --rt-probe JR-East.Yamanote
enum RealtimeProbe {
    static func run(railwayId: String) {
        guard let key = ProcessInfo.processInfo.environment["ODPT_API_KEY"], !key.isEmpty else {
            print("Set ODPT_API_KEY, e.g.:")
            print("  ODPT_API_KEY=yourkey swift run TrainMenu --rt-probe JR-East.Yamanote")
            exit(1)
        }
        let client = ODPTClient(consumerKey: key)
        let sem = DispatchSemaphore(value: 0)
        Task {
            defer { sem.signal() }

            // Per-train delays (odpt:Train) — usually empty for a Center key.
            do {
                let trains = try await client.trains(railwayId: railwayId)
                print("odpt:Train — \(trains.count) trains running on \(railwayId)")
                for t in trains.prefix(8) {
                    print("  \(t.trainNumber ?? "?")\tdelay=\(t.delaySeconds ?? 0)s\t\(t.railDirection ?? "")")
                }
            } catch {
                print("odpt:Train — failed: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }

            // Line status (odpt:TrainInformation) — works with a Center key.
            do {
                let infos = try await client.trainInformation()
                print("\nodpt:TrainInformation — \(infos.count) lines visible")
                if let m = infos.first(where: { ($0.railway ?? "").hasSuffix(railwayId) }) {
                    let status = m.status?["ja"] ?? m.status?["en"] ?? "normal"
                    let text = m.text?["ja"] ?? m.text?["en"] ?? "?"
                    print("✓ \(railwayId): status=\(status)  text=\(text)")
                } else {
                    print("• no status entry for \(railwayId) (operator may omit when normal)")
                }
            } catch {
                print("odpt:TrainInformation — failed: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
                exit(1)
            }
        }
        sem.wait()
    }
}
