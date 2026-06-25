import Foundation

/// Entry point. `--selftest` runs a headless check of the data pipeline and
/// exits; otherwise the SwiftUI menu bar app launches.
@main
struct Main {
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()
            return
        }
        TrainMenuApp.main()
    }
}
