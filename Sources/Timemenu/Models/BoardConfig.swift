import Foundation

/// A saved departures board: which line, which station, which direction.
struct BoardConfig: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var railwayId: String
    var stationId: String
    var directionId: String
}
