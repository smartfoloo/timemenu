import Foundation

/// Entry point. `--selftest` runs a headless check of the data pipeline and
/// exits; otherwise the SwiftUI menu bar app launches.
@main
struct Main {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--selftest") {
            SelfTest.run()
            return
        }
        if let idx = args.firstIndex(of: "--rt-probe") {
            let railway = idx + 1 < args.count ? args[idx + 1] : "JR-East.Yamanote"
            RealtimeProbe.run(railwayId: railway)
            return
        }
        TimemenuApp.main()
    }
}
