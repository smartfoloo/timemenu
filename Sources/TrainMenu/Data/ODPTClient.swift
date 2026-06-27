import Foundation

/// One live train from ODPT's `odpt:Train` endpoint. Only the fields we use are
/// decoded. IDs come prefixed (e.g. "odpt.Railway:JR-East.Yamanote"); our bundled
/// data uses the unprefixed form ("JR-East.Yamanote").
struct ODPTTrain: Decodable {
    let railway: String?         // "odpt.Railway:JR-East.Yamanote"
    let trainNumber: String?     // "400G" — matches our timetable's `n`
    let delaySeconds: Int?       // odpt:delay, in seconds
    let railDirection: String?

    enum CodingKeys: String, CodingKey {
        case railway = "odpt:railway"
        case trainNumber = "odpt:trainNumber"
        case delaySeconds = "odpt:delay"
        case railDirection = "odpt:railDirection"
    }
}

/// One line's operational status from `odpt:TrainInformation`. `status` is only
/// present when there's a disruption; when normal, only `text` ("平常運行") is set.
struct ODPTTrainInformation: Decodable {
    let railway: String?
    let status: [String: String]?   // odpt:trainInformationStatus
    let text: [String: String]?     // odpt:trainInformationText

    enum CodingKeys: String, CodingKey {
        case railway = "odpt:railway"
        case status = "odpt:trainInformationStatus"
        case text = "odpt:trainInformationText"
    }
}

/// UI-facing line status resolved from `ODPTTrainInformation`.
struct LineStatus {
    let text: Localized           // human description (normal phrase or disruption detail)
    let statusLabel: Localized?   // short label when abnormal (e.g. "遅延")

    /// No `statusLabel` means the operator is reporting normal service.
    var isNormal: Bool { statusLabel == nil }

    func display(_ language: String) -> String {
        let t = text.localized(language)
        return t.isEmpty ? (statusLabel?.localized(language) ?? "") : t
    }
}

enum ODPTError: LocalizedError {
    case badURL
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad request URL"
        case .http(401), .http(403): return "Invalid or unauthorized API key"
        case .http(429): return "Rate limit exceeded — try again shortly"
        case .http(let code): return "Server error (HTTP \(code))"
        }
    }
}

/// Thin async client for the ODPT real-time train API.
struct ODPTClient {
    let consumerKey: String
    var baseURL = "https://api.odpt.org/api/v4/odpt:Train"
    var infoURL = "https://api.odpt.org/api/v4/odpt:TrainInformation"

    /// All line statuses the key can see (one request covers every board).
    func trainInformation() async throws -> [ODPTTrainInformation] {
        guard var comps = URLComponents(string: infoURL) else { throw ODPTError.badURL }
        comps.queryItems = [URLQueryItem(name: "acl:consumerKey", value: consumerKey)]
        guard let url = comps.url else { throw ODPTError.badURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ODPTError.http(http.statusCode)
        }
        return try JSONDecoder().decode([ODPTTrainInformation].self, from: data)
    }

    /// Live trains for a line. `railwayId` is our unprefixed id (e.g.
    /// "JR-East.Yamanote"); the API is queried with the "odpt.Railway:" prefix.
    func trains(railwayId: String) async throws -> [ODPTTrain] {
        guard var comps = URLComponents(string: baseURL) else { throw ODPTError.badURL }
        comps.queryItems = [
            URLQueryItem(name: "odpt:railway", value: "odpt.Railway:\(railwayId)"),
            URLQueryItem(name: "acl:consumerKey", value: consumerKey),
        ]
        guard let url = comps.url else { throw ODPTError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ODPTError.http(http.statusCode)
        }
        return try JSONDecoder().decode([ODPTTrain].self, from: data)
    }
}
