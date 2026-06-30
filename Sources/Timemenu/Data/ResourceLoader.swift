import Foundation

enum ResourceError: Error, CustomStringConvertible {
    case missing(String)

    var description: String {
        switch self {
        case .missing(let name): return "bundled resource not found: \(name)"
        }
    }
}

/// Loads the compressed (raw-DEFLATE) JSON resources from the app bundle and
/// decodes them. The snapshot is produced by Scripts/build-data-snapshot.py.
enum ResourceLoader {
    private static let decoder = JSONDecoder()

    /// Decompress a raw-DEFLATE blob (RFC 1951) into bytes.
    static func inflate(_ compressed: Data) throws -> Data {
        try (compressed as NSData).decompressed(using: .zlib) as Data
    }

    /// Locate `<subdir>/<name>.deflate` in the bundle, inflate, and JSON-decode.
    static func load<T: Decodable>(_ type: T.Type, name: String, subdir: String) throws -> T {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "deflate", subdirectory: subdir
        ) else {
            throw ResourceError.missing("\(subdir)/\(name).deflate")
        }
        let compressed = try Data(contentsOf: url)
        let json = try inflate(compressed)
        return try decoder.decode(T.self, from: json)
    }
}
