//
//  APICodingSupport.swift
//  romm
//
//  Encoding/decoding helpers shared by all API model types.
//

import Foundation

// MARK: - JSONEncodable

protocol JSONEncodable {
    func encodeToJSON() -> Any
}

extension Bool: JSONEncodable { func encodeToJSON() -> Any { self } }
extension Float: JSONEncodable { func encodeToJSON() -> Any { self } }
extension Int: JSONEncodable { func encodeToJSON() -> Any { self } }
extension Int32: JSONEncodable { func encodeToJSON() -> Any { self } }
extension Int64: JSONEncodable { func encodeToJSON() -> Any { self } }
extension Double: JSONEncodable { func encodeToJSON() -> Any { self } }
extension Decimal: JSONEncodable { func encodeToJSON() -> Any { self } }
extension String: JSONEncodable { func encodeToJSON() -> Any { self } }
extension URL: JSONEncodable { func encodeToJSON() -> Any { self } }
extension UUID: JSONEncodable { func encodeToJSON() -> Any { self } }

extension RawRepresentable where RawValue: JSONEncodable {
    func encodeToJSON() -> Any { rawValue }
}

extension Array: JSONEncodable {
    func encodeToJSON() -> Any { map(encodeIfPossible) }
}

extension Set: JSONEncodable {
    func encodeToJSON() -> Any { Array(self).encodeToJSON() }
}

extension Dictionary: JSONEncodable {
    func encodeToJSON() -> Any {
        var dict = [AnyHashable: Any]()
        for (key, value) in self { dict[key] = encodeIfPossible(value) }
        return dict
    }
}

extension Data: JSONEncodable {
    func encodeToJSON() -> Any { base64EncodedString(options: Data.Base64EncodingOptions()) }
}

extension Date: JSONEncodable {
    func encodeToJSON() -> Any { ISO8601DateFormatter().string(from: self) }
}

extension JSONEncodable where Self: Encodable {
    func encodeToJSON() -> Any {
        guard let data = try? JSONEncoder().encode(self) else {
            fatalError("Could not encode to json: \(self)")
        }
        return data.encodeToJSON()
    }
}

private func encodeIfPossible<T>(_ object: T) -> Any {
    (object as? JSONEncodable)?.encodeToJSON() ?? object
}

// MARK: - String as CodingKey

extension String: CodingKey {
    public var stringValue: String { self }
    public init?(stringValue: String) { self.init(stringLiteral: stringValue) }
    public var intValue: Int? { nil }
    public init?(intValue: Int) { nil }
}

// MARK: - KeyedEncodingContainerProtocol Helpers

extension KeyedEncodingContainerProtocol {
    public mutating func encodeArray<T: Encodable>(_ values: [T], forKey key: Self.Key) throws {
        var arrayContainer = nestedUnkeyedContainer(forKey: key)
        try arrayContainer.encode(contentsOf: values)
    }

    public mutating func encodeArrayIfPresent<T: Encodable>(_ values: [T]?, forKey key: Self.Key) throws {
        if let values { try encodeArray(values, forKey: key) }
    }

    public mutating func encodeMap<T: Encodable>(_ pairs: [Self.Key: T]) throws {
        for (key, value) in pairs { try encode(value, forKey: key) }
    }

    public mutating func encodeMapIfPresent<T: Encodable>(_ pairs: [Self.Key: T]?) throws {
        if let pairs { try encodeMap(pairs) }
    }

    public mutating func encode(_ value: Decimal, forKey key: Self.Key) throws {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        let formatted = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
        try encode(formatted, forKey: key)
    }

    public mutating func encodeIfPresent(_ value: Decimal?, forKey key: Self.Key) throws {
        if let value { try encode(value, forKey: key) }
    }
}

// MARK: - KeyedDecodingContainerProtocol Helpers

extension KeyedDecodingContainerProtocol {
    public func decodeArray<T: Decodable>(_ type: T.Type, forKey key: Self.Key) throws -> [T] {
        var result = [T]()
        var nested = try nestedUnkeyedContainer(forKey: key)
        while !nested.isAtEnd { result.append(try nested.decode(T.self)) }
        return result
    }

    public func decodeArrayIfPresent<T: Decodable>(_ type: T.Type, forKey key: Self.Key) throws -> [T]? {
        contains(key) ? try decodeArray(type, forKey: key) : nil
    }

    public func decodeMap<T: Decodable>(_ type: T.Type, excludedKeys: Set<Self.Key>) throws -> [Self.Key: T] {
        var map: [Self.Key: T] = [:]
        for key in allKeys where !excludedKeys.contains(key) {
            map[key] = try decode(T.self, forKey: key)
        }
        return map
    }

    public func decode(_ type: Decimal.Type, forKey key: Self.Key) throws -> Decimal {
        let string = try decode(String.self, forKey: key)
        guard let value = Decimal(string: string) else {
            throw DecodingError.typeMismatch(type, .init(codingPath: [key], debugDescription: "Cannot convert '\(string)' to Decimal"))
        }
        return value
    }

    public func decodeIfPresent(_ type: Decimal.Type, forKey key: Self.Key) throws -> Decimal? {
        guard let string = try decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let value = Decimal(string: string) else {
            throw DecodingError.typeMismatch(type, .init(codingPath: [key], debugDescription: "Cannot convert '\(string)' to Decimal"))
        }
        return value
    }
}

// MARK: - Flexible Date Decoding

extension KeyedDecodingContainer {
    func decodeFlexibleDate(forKey key: Key) throws -> Date? {
        guard let string = try decodeIfPresent(String.self, forKey: key) else { return nil }
        return parseFlexibleDate(from: string)
    }

    func decodeFlexibleDate(forKey key: Key) throws -> Date {
        let string = try decode(String.self, forKey: key)
        guard let date = parseFlexibleDate(from: string) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Cannot parse date from: \(string)")
        }
        return date
    }
}

private func parseFlexibleDate(from string: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: string) { return date }
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: string) { return date }
    iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withFractionalSeconds]
    if let date = iso.date(from: string) { return date }
    iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
    return iso.date(from: string)
}