//
//  UInt+HexCodable.swift
//  
//
//  Created by Yehor Popovych on 06.01.2023.
//

import Foundation
import ScaleCodec

private let maxJsonSafeInteger: UInt64 = 2^53 - 1

public struct TrimmedHex: Codable {
    public struct InitError: Error {
        public let desc: String
    }
    
    public let data: Data
    
    public init(data: Data) { self.data = data }
    
    public init(string: String) throws {
        guard string != "0x0" else {
            self.init(data: Data())
            return
        }
        var string = string
        if string.hasPrefix("0x") {
            string.removeFirst(2)
        }
        if string.count % 2 == 1 {
            string.insert("0", at: string.startIndex)
        }
        guard let data = Data(hex: string) else {
            throw InitError(desc: "Bad hex value \(string)")
        }
        self.init(data: data)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            try self.init(string: string)
        } catch let e as InitError {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: e.desc)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard !data.isEmpty else {
            try container.encode("0x0")
            return
        }
        var hex = data.hex(prefix: false)
        if (hex[hex.startIndex] == "0") {
            hex.remove(at: hex.startIndex)
        }
        hex.insert(contentsOf: "0x", at: hex.startIndex)
        try container.encode(hex)
    }
}

public struct UIntHex<T: UnsignedInteger> {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

extension UIntHex: Decodable where T: DataInitalizable {
    public init(string: String) throws {
        let hex = try TrimmedHex(string: string)
        guard !hex.data.isEmpty else {
            self.init(0)
            return
        }
        guard let val = T(data: hex.data, littleEndian: false, trimmed: true) else {
            throw TrimmedHex.InitError(desc: "Can't initialize \(T.self) from \(string)")
        }
        self.init(val)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            try self.init(string: string)
        } catch let e as TrimmedHex.InitError {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: e.desc)
        }
    }
}

extension UIntHex: Encodable where T: DataSerializable {
    public func encode(to encoder: Encoder) throws {
        let data = value == 0
            ? Data() : value.data(littleEndian: false, trimmed: true)
        try TrimmedHex(data: data).encode(to: encoder)
    }
}

public struct HexOrNumber<T: UnsignedInteger> {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

extension HexOrNumber: Decodable where T: Decodable & DataInitalizable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(T.self) {
            self.init(value)
        } else {
            self.init(try container.decode(UIntHex<T>.self).value)
        }
    }
}

extension HexOrNumber: Encodable where T: Encodable & DataSerializable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if UInt64(clamping: value) > maxJsonSafeInteger {
            try container.encode(UIntHex(value))
        } else {
            try container.encode(value)
        }
    }
}