import Foundation

/// Holds the small metadata lookup tables (railways, stations, directions, ...)
/// loaded once at launch, plus the railwayId -> timetable-file index. The large
/// per-line timetables are loaded lazily by `TimetableRepo`.
final class DataStore {
    static let metaSubdir = "Data/meta"

    let railways: [Railway]
    let stations: [Station]
    let directions: [RailDirection]
    let trainTypes: [TrainType]
    let vehicles: [TrainVehicle]
    /// Interchange groups: each group is a list of clusters, each cluster a list
    /// of station ids that are the same physical place across lines.
    let stationGroups: [[[String]]]
    /// railwayId -> list of railway ids it through-runs onto.
    let throughServices: [String: [String]]
    /// railwayId -> timetable resource stem (e.g. "JR-East.Yamanote" -> "jreast-yamanote").
    let timetableIndex: [String: String]

    let railwaysById: [String: Railway]
    let stationsById: [String: Station]
    let directionsById: [String: RailDirection]
    let trainTypesById: [String: TrainType]
    let vehiclesById: [String: TrainVehicle]

    init() throws {
        let sub = DataStore.metaSubdir
        railways = try ResourceLoader.load([Railway].self, name: "railways", subdir: sub)
        stations = try ResourceLoader.load([Station].self, name: "stations", subdir: sub)
        directions = try ResourceLoader.load([RailDirection].self, name: "rail-directions", subdir: sub)
        trainTypes = try ResourceLoader.load([TrainType].self, name: "train-types", subdir: sub)
        vehicles = try ResourceLoader.load([TrainVehicle].self, name: "train-vehicles", subdir: sub)
        stationGroups = try ResourceLoader.load([[[String]]].self, name: "station-groups", subdir: sub)
        throughServices = try ResourceLoader.load([String: [String]].self, name: "through-services", subdir: sub)
        timetableIndex = try ResourceLoader.load([String: String].self, name: "railway-timetable-index", subdir: sub)

        railwaysById = Dictionary(railways.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        stationsById = Dictionary(stations.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        directionsById = Dictionary(directions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        trainTypesById = Dictionary(trainTypes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        vehiclesById = Dictionary(vehicles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: - Display helpers

    func railwayTitle(_ id: String, language: String = "en") -> String {
        railwaysById[id]?.title.localized(language) ?? id
    }

    func stationTitle(_ id: String, language: String = "en") -> String {
        // Fall back to the last id component if the station isn't in the table
        // (e.g. a through-service destination on an unlisted line).
        stationsById[id]?.title.localized(language)
            ?? id.split(separator: ".").last.map(String.init)
            ?? id
    }

    func directionTitle(_ id: String, language: String = "en") -> String {
        directionsById[id]?.title.localized(language) ?? id
    }

    func trainTypeTitle(_ id: String?, language: String = "en") -> String? {
        guard let id else { return nil }
        return trainTypesById[id]?.title.localized(language) ?? id
    }
}
