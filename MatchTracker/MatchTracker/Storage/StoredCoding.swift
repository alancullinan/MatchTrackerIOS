import Foundation

/// The JSON used for the encoded parts of stored records. Keys are sorted so the
/// same value always encodes to the same bytes, and an unchanged match is never
/// re-synced just because its JSON came out in a different order.
enum StoredCoding {
    static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, _ data: Data, field: String) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw StoredDataError.unreadable(field: field, underlying: error)
        }
    }

    static func enumCase<Value: RawRepresentable<String>>(_ type: Value.Type, _ rawValue: String, field: String) throws -> Value {
        guard let value = Value(rawValue: rawValue) else {
            throw StoredDataError.unknownCase(field: field, rawValue: rawValue)
        }
        return value
    }
}

enum StoredDataError: Error {
    /// A case name this version of the app doesn't know, e.g. written by a newer version.
    case unknownCase(field: String, rawValue: String)
    case unreadable(field: String, underlying: any Error)
}
