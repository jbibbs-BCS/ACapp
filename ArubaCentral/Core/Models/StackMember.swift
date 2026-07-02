import Foundation

struct StackMember: Codable, Identifiable, Equatable {
    let serial: String
    let model: String?
    let status: DeviceStatus
    let role: String?

    var id: String { serial }

    // NCA stack-member response schema is not fully documented; try every plausible key name.
    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)

        func str(_ candidates: String...) -> String? {
            candidates.lazy.compactMap {
                try? c.decode(String.self, forKey: AnyKey(stringValue: $0))
            }.first
        }

        serial = str("serial", "serialNumber", "memberSerial", "id") ?? UUID().uuidString
        model  = str("model", "memberModel", "productName")
        role   = str("role", "memberRole", "memberType", "type")

        // Decode status via DeviceStatus (handles "Up"/"Online"/"Down"/"Offline")
        if let raw = str("status", "operStatus", "memberStatus", "state") {
            status = (try? DeviceStatus(from: SingleValueDecoder(raw))) ?? .unknown
        } else {
            status = .unknown
        }
    }

    init(serial: String, model: String?, status: DeviceStatus, role: String?) {
        self.serial = serial
        self.model  = model
        self.status = status
        self.role   = role
    }
}

// Minimal single-value decoder used to re-decode a String through DeviceStatus.init(from:)
private struct SingleValueDecoder: Decoder {
    let value: String
    init(_ value: String) { self.value = value }
    var codingPath: [CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    func container<K: CodingKey>(keyedBy: K.Type) throws -> KeyedDecodingContainer<K> {
        throw DecodingError.typeMismatch(K.self, .init(codingPath: [], debugDescription: ""))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(String.self, .init(codingPath: [], debugDescription: ""))
    }
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleValue(value)
    }

    private struct SingleValue: SingleValueDecodingContainer {
        let value: String
        var codingPath: [CodingKey] { [] }
        init(_ v: String) { value = v }
        func decodeNil() -> Bool { false }
        func decode(_ type: Bool.Type)   throws -> Bool   { throw err() }
        func decode(_ type: Int.Type)    throws -> Int    { throw err() }
        func decode(_ type: Int8.Type)   throws -> Int8   { throw err() }
        func decode(_ type: Int16.Type)  throws -> Int16  { throw err() }
        func decode(_ type: Int32.Type)  throws -> Int32  { throw err() }
        func decode(_ type: Int64.Type)  throws -> Int64  { throw err() }
        func decode(_ type: UInt.Type)   throws -> UInt   { throw err() }
        func decode(_ type: UInt8.Type)  throws -> UInt8  { throw err() }
        func decode(_ type: UInt16.Type) throws -> UInt16 { throw err() }
        func decode(_ type: UInt32.Type) throws -> UInt32 { throw err() }
        func decode(_ type: UInt64.Type) throws -> UInt64 { throw err() }
        func decode(_ type: Float.Type)  throws -> Float  { throw err() }
        func decode(_ type: Double.Type) throws -> Double { throw err() }
        func decode(_ type: String.Type) throws -> String { value }
        func decode<T: Decodable>(_ type: T.Type) throws -> T { throw err() }
        private func err() -> DecodingError {
            .typeMismatch(String.self, .init(codingPath: [], debugDescription: ""))
        }
    }
}
