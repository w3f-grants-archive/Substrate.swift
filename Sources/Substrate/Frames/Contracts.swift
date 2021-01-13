//
//  Contracts.swift
//  
//
//  Created by Yehor Popovych on 1/13/21.
//

import Foundation
import ScaleCodec

public protocol Contracts: Balances {}

open class ContractsModule<C: Contracts>: ModuleProtocol {
    public typealias Frame = C
    
    public static var NAME: String { "Contracts" }
    
    public init() {}
    
    open func registerEventsCallsAndTypes<R>(in registry: R) throws where R : TypeRegistryProtocol {
        try registry.register(type: Gas.self, as: .type(name: "Gas"))
        try registry.register(type: SCompact<Gas>.self, as: .compact(type: .type(name: "Gas")))
        try registry.register(call: ContractsPutCodeCall<C>.self)
        try registry.register(call: ContractsInstantiateCall<C>.self)
        try registry.register(call: ConstractsCallCall<C>.self)
        try registry.register(event: ConstractsCodeStoredEvent<C>.self)
        try registry.register(event: ContractsInstantiatedEvent<C>.self)
        try registry.register(event: ContractsContractExecutionEvent<C>.self)
    }
}

public typealias Gas = UInt64

/// Stores the given binary Wasm code into the chain's storage and returns
/// its `codehash`.
/// You can instantiate contracts only with stored code.
public struct ContractsPutCodeCall<C: Contracts> {
    /// Wasm blob.
    public let code: Data
}

extension ContractsPutCodeCall: Call {
    public typealias Module = ContractsModule<C>
    
    public static var FUNCTION: String { "put_code" }
    
    public init(decodingParamsFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        code = try decoder.decode()
    }
    
    public var params: [ScaleDynamicCodable] { [code] }
}

/// Creates a new contract from the `codehash` generated by `put_code`,
/// optionally transferring some balance.
///
/// Creation is executed as follows:
///
/// - The destination address is computed based on the sender and hash of
/// the code.
/// - The smart-contract account is instantiated at the computed address.
/// - The `ctor_code` is executed in the context of the newly-instantiated
/// account. Buffer returned after the execution is saved as the `code`https://www.bbc.co.uk/
/// of the account. That code will be invoked upon any call received by
/// this account.
/// - The contract is initialized.
public struct ContractsInstantiateCall<C: Contracts> {
    /// Initial balance transfered to the contract.
    public let endowment: C.TBalance
    /// Gas limit.
    public let gasLimit: Gas
    /// Code hash returned by the put_code call.
    public let codeHash: C.THash
    /// Data to initialize the contract with.
    public let data: Data
}

extension ContractsInstantiateCall: Call {
    public typealias Module = ContractsModule<C>
    
    public static var FUNCTION: String { "instantiate" }
    
    public init(decodingParamsFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        endowment = try decoder.decode(.compact)
        gasLimit = try decoder.decode(.compact)
        codeHash = try decoder.decode()
        data = try decoder.decode()
    }
    
    public var params: [ScaleDynamicCodable] { [SCompact(endowment), SCompact(gasLimit), codeHash, data] }
}

/// Makes a call to an account, optionally transferring some balance.
///
/// * If the account is a smart-contract account, the associated code will
///  be executed and any value will be transferred.
/// * If the account is a regular account, any value will be transferred.
/// * If no account exists and the call value is not less than
/// `existential_deposit`, a regular account will be created and any value
///  will be transferred.
public struct ConstractsCallCall<C: Contracts> {
    /// Address of the contract.
    public let destination: C.TAddress
    /// Value to transfer to the contract.
    public let value: C.TBalance
    /// Gas limit.
    public let gasLimit: Gas
    /// Data to send to the contract.
    public let data: Data
}

extension ConstractsCallCall: Call {
    public typealias Module = ContractsModule<C>
    
    public static var FUNCTION: String { "call" }
    
    public init(decodingParamsFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        destination = try C.TAddress(from: decoder, registry: registry)
        value = try decoder.decode(.compact)
        gasLimit = try decoder.decode(.compact)
        data = try decoder.decode()
    }
    
    public var params: [ScaleDynamicCodable] { [destination, SCompact(value), SCompact(gasLimit), data] }
}

/// Code stored event.
public struct ConstractsCodeStoredEvent<C: Contracts> {
    /// Code hash of the contract.
    public let codeHash: C.THash
    // Dynamic type
    private let type: DType
}

extension ConstractsCodeStoredEvent: Event {
    public typealias Module = ContractsModule<C>
    
    public static var EVENT: String { "CodeStored" }
    
    public init(decodingDataFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        codeHash = try decoder.decode()
        type = try registry.type(of: C.THash.self)
    }
    
    public var data: DValue { .native(type: type, value: codeHash) }
}

/// Instantiated event.
public struct ContractsInstantiatedEvent<C: Contracts> {
    /// Caller that instantiated the contract.
    public let caller: C.TAccountId
    /// The address of the contract.
    public let contract: C.TAccountId
    /// dynamic types
    private let type: DType
}

extension ContractsInstantiatedEvent: Event {
    public typealias Module = ContractsModule<C>
    
    public static var EVENT: String { "Instantiated" }
    
    public init(decodingDataFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        caller = try C.TAccountId(from: decoder, registry: registry)
        contract = try C.TAccountId(from: decoder, registry: registry)
        type = try registry.type(of: C.TAccountId.self)
    }
    
    public var data: DValue {
        .collection(values: [
            .native(type: type, value: caller),
            .native(type: type, value: contract)
        ])
        
    }
}

/// Contract execution event.
///
/// Emitted upon successful execution of a contract, if any contract events were produced.
public struct ContractsContractExecutionEvent<C: Contracts> {
    /// Caller of the contract.
    public let caller: C.TAccountId
    /// SCALE encoded contract event data.
    public let callData: Data
    // dynamic types
    private let types: (caller: DType, data: DType)
    
    public func parseStatic<D: ScaleDecodable>(_ t: D.Type) throws -> D {
        return try SCALE.default.decoder(data: callData).decode()
    }
    
    public func parseDynamic<D: ScaleDynamicDecodable>(_ t: D.Type, with registry: TypeRegistryProtocol) throws -> D {
        return try D(from: SCALE.default.decoder(data: callData), registry: registry)
    }
}

extension ContractsContractExecutionEvent: Event {
    public typealias Module = ContractsModule<C>
    
    public static var EVENT: String { "ContractExecution" }
    
    public init(decodingDataFrom decoder: ScaleDecoder, registry: TypeRegistryProtocol) throws {
        caller = try C.TAccountId(from: decoder, registry: registry)
        callData = try decoder.decode()
        types = try (caller: registry.type(of: C.TAccountId.self), data: registry.type(of: Data.self))
    }
    
    public var data: DValue {
        .collection(values: [
            .native(type: types.caller, value: caller),
            .native(type: types.data, value: callData)
        ])
    }
}
