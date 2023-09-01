//
//  BatchCalls.swift
//  
//
//  Created by Yehor Popovych on 17/08/2023.
//

import Foundation
import ScaleCodec

public protocol BatchCallCommon: SomeBatchCall, RuntimeValidatableComposite {}

public extension BatchCallCommon {
    func add(_ call: any Call) -> Self { Self(calls: calls + [call]) }
    
    @inlinable static var pallet: String { "Utility" }
    
    init<D: ScaleCodec.Decoder>(from decoder: inout D, as type: RuntimeType.Id, runtime: Runtime) throws {
        let modIndex = try decoder.decode(.enumCaseId)
        let callIndex = try decoder.decode(.enumCaseId)
        guard let info = runtime.resolve(callName: callIndex, pallet: modIndex) else {
            throw CallCodingError.callNotFound(index: callIndex, pallet: modIndex)
        }
        guard Self.pallet == info.pallet && Self.name == info.name else {
            throw CallCodingError.foundWrongCall(found: (name: info.name, pallet: info.pallet),
                                                 expected: (name: Self.name, pallet: Self.pallet))
        }
        let calls = try Array<AnyCall<RuntimeType.Id>>(from: &decoder) { decoder in
            try AnyCall(from: &decoder, as: type, runtime: runtime)
        }
        self.init(calls: calls)
    }
    
    func encode<E: ScaleCodec.Encoder>(in encoder: inout E, as type: RuntimeType.Id, runtime: Runtime) throws {
        guard let info = runtime.resolve(callIndex: name, pallet: pallet) else {
            throw CallCodingError.callNotFound(name: name, pallet: pallet)
        }
        try encoder.encode(info.pallet, .enumCaseId)
        try encoder.encode(info.index, .enumCaseId)
        try calls.encode(in: &encoder) { call, enc in
            try runtime.encode(value: call, in: &enc) { _ in type }
        }
    }
    
    static func validate(fields ids: [RuntimeType.Id], runtime: any Runtime) -> Result<Void, ValidationError>
    {
        guard ids.count == 1 else {
            return .failure(.wrongFieldsCount(for: Self.self, expected: 1, got: ids.count))
        }
        guard let type = runtime.resolve(type: ids[0]) else {
            return .failure(.childError(for: Self.self, error: .typeNotFound(ids[0])))
        }
        guard case .sequence(of: let callType) = type.definition else {
            return .failure(.childError(for: Self.self, error: .wrongType(got: type, for: "Array<Call>")))
        }
        return AnyCall<RuntimeType.Id>.validate(runtime: runtime, type: callType)
            .mapError { .childError(for: Self.self, error: $0) }
    }
}

public struct BatchCall: BatchCallCommon {
    public let calls: [any Call]
    public init(calls: [any Call]) {
        self.calls = calls
    }
    public static let name = "batch"
}

public struct BatchAllCall: BatchCallCommon {
    public let calls: [any Call]
    public init(calls: [any Call]) {
        self.calls = calls
    }
    public static let name = "batch_all"
}
