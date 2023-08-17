//
//  RuntimeConfig.swift
//  
//
//  Created by Yehor Popovych on 29.12.2022.
//

import Foundation
import ScaleCodec

public protocol Config {
    associatedtype THasher: FixedHasher
    associatedtype TIndex: UnsignedInteger & DataConvertible & CompactCodable & Swift.Codable & RuntimeCodable
    associatedtype TAccountId: AccountId
    associatedtype TAddress: Address<TAccountId>
    associatedtype TSignature: Signature
    associatedtype TBlock: SomeBlock where TBlock.THeader.THasher == THasher
    associatedtype TChainBlock: SomeChainBlock<TBlock>
    
    associatedtype TExtrinsicEra: SomeExtrinsicEra
    associatedtype TExtrinsicPayment: ValueRepresentable
    associatedtype TBlockEvents: SomeBlockEvents
    associatedtype TExtrinsicFailureEvent: SomeExtrinsicFailureEvent
    associatedtype TDispatchError: CallError
    associatedtype TTransactionValidityError: CallError
    associatedtype TDispatchInfo: RuntimeDynamicDecodable
    associatedtype TFeeDetails: RuntimeDynamicDecodable
    associatedtype TTransactionStatus: SomeTransactionStatus<TBlock.THeader.THasher.THash>
    associatedtype TSystemProperties: SystemProperties
    associatedtype TRuntimeVersion: RuntimeVersion
    associatedtype TStorageChangeSet: SomeStorageChangeSet<TBlock.THeader.THasher.THash>
    associatedtype TExtrinsicManager: ExtrinsicManager<Self>
    
    // Metadata Info Providers
    func blockType(metadata: any Metadata) throws -> RuntimeType.Info
    func hashType(metadata: any Metadata) throws -> RuntimeType.Info
    func dispatchInfoType(metadata: any Metadata) throws -> RuntimeType.Info
    func feeDetailsType(metadata: any Metadata) throws -> RuntimeType.Info
    func dispatchErrorType(metadata: any Metadata) throws -> RuntimeType.Info
    func transactionValidityErrorType(metadata: any Metadata) throws -> RuntimeType.Info
    func accountType(metadata: any Metadata, address: RuntimeType.Info) throws -> RuntimeType.Info
    // Сan be safely removed after removing metadata v14 (v15 has them)
    func extrinsicTypes(metadata: any Metadata) throws -> (call: RuntimeType.Info, addr: RuntimeType.Info,
                                                           signature: RuntimeType.Info, extra: RuntimeType.Info)
    // Object Builders
    func hasher(metadata: any Metadata) throws -> THasher
    func defaultPayment(runtime: any Runtime) throws -> TExtrinsicPayment
    func eventsStorageKey(runtime: any Runtime) throws -> any StorageKey<TBlockEvents>
    func queryInfoCall(extrinsic: Data, runtime: any Runtime) throws -> any RuntimeCall<TDispatchInfo>
    func queryFeeDetailsCall(extrinsic: Data, runtime: any Runtime) throws -> any RuntimeCall<TFeeDetails>
    func metadataVersionsCall() throws -> any StaticCodableRuntimeCall<[UInt32]>
    func metadataAtVersionCall(version: UInt32) throws -> any StaticCodableRuntimeCall<Optional<OpaqueMetadata>>
    func extrinsicManager() throws -> TExtrinsicManager
    func customCoders() throws -> [RuntimeCustomDynamicCoder]
    // If you want your own Scale Codec coders
    func encoder() -> ScaleCodec.Encoder
    func encoder(reservedCapacity count: Int) -> ScaleCodec.Encoder
    func decoder(data: Data) -> ScaleCodec.Decoder
}

// Config that supports batches
public protocol BatchSupportedConfig: Config {
    associatedtype TBatchCall: SomeBatchCall
    associatedtype TBatchAllCall: SomeBatchCall
    
    func isBatchSupported(metadata: any Metadata) -> Bool
}

// Default isBatchSupported implementation
public extension BatchSupportedConfig {
    func isBatchSupported(metadata: Metadata) -> Bool {
        metadata.resolve(pallet: TBatchCall.pallet)?.callIndex(name: TBatchCall.name) != nil &&
        metadata.resolve(pallet: TBatchAllCall.pallet)?.callIndex(name: TBatchAllCall.name) != nil
    }
}

// Type for Config registrations. Provides better constructors for RootApi
public struct ConfigRegistry<C: Config> {
    public let config: C
    @inlinable public init(config: C) { self.config = config }
}

// Default constructors
public extension Config {
    @inlinable
    func encoder() -> ScaleCodec.Encoder { ScaleCodec.encoder() }
    
    @inlinable
    func encoder(reservedCapacity count: Int) -> ScaleCodec.Encoder {
        ScaleCodec.encoder(reservedCapacity: count)
    }
    
    @inlinable
    func decoder(data: Data) -> ScaleCodec.Decoder { ScaleCodec.decoder(from: data) }
    
    @inlinable
    func eventsStorageKey(runtime: any Runtime) throws -> any StorageKey<TBlockEvents> {
        AnyStorageKey(name: "Events", pallet: "System", path: [])
    }
    
    @inlinable
    func metadataVersionsCall() throws -> any StaticCodableRuntimeCall<[UInt32]> {
        MetadataVersionsRuntimeCall()
    }
    
    @inlinable
    func metadataAtVersionCall(version: UInt32) throws -> any StaticCodableRuntimeCall<Optional<OpaqueMetadata>> {
        MetadataAtVersionRuntimeCall(version: version)
    }
    
    @inlinable
    func queryInfoCall(extrinsic: Data, runtime: any Runtime) throws -> any RuntimeCall<TDispatchInfo> {
        AnyRuntimeCall(api: "TransactionPaymentApi",
                       method: "query_info",
                       params: [extrinsic, extrinsic.count])
    }
    
    @inlinable
    func queryFeeDetailsCall(extrinsic: Data, runtime: any Runtime) throws -> any RuntimeCall<TFeeDetails> {
        AnyRuntimeCall(api: "TransactionPaymentApi",
                       method: "query_fee_details",
                       params: [extrinsic, extrinsic.count])
    }
    
    @inlinable
    func customCoders() throws -> [RuntimeCustomDynamicCoder] {
        [ExtrinsicCustomDynamicCoder(name: "UncheckedExtrinsic")]
    }
}

public extension Config where THasher: StaticHasher {
    // Static hasher creates Hash without type lookup
    func hashType(metadata: any Metadata) throws -> RuntimeType.Info {
        throw RuntimeType.IdNeverCalledError()
    }
    // Static Hasher can be returned by singleton instance
    func hasher(metadata: Metadata) throws -> THasher { THasher.instance }
}

// Static Block doesn't need runtime type
public extension Config where TBlock: StaticBlock {
    func blockType(metadata: Metadata) throws -> RuntimeType.Info {
        throw RuntimeType.IdNeverCalledError()
    }
}

// Static Transaction Validity Error doesn't need runtime type
public extension Config where TTransactionValidityError: StaticCallError {
    func transactionValidityErrorType(metadata: any Metadata) throws -> RuntimeType.Info {
        throw RuntimeType.IdNeverCalledError()
    }
}

// Static Dispatch Error doesn't need runtime type
public extension Config where TDispatchError: StaticCallError {
    func dispatchErrorType(metadata: any Metadata) throws -> RuntimeType.Info {
        throw RuntimeType.IdNeverCalledError()
    }
}

// Static Dispatch Info doesn't need runtime type
public extension Config where TDispatchInfo: RuntimeDecodable {
    func dispatchInfoType(metadata: any Metadata) throws -> RuntimeType.Info {
        throw RuntimeType.IdNeverCalledError()
    }
}

// Static Fee Details doesn't need runtime type
public extension Config where TFeeDetails: RuntimeDecodable {
    func feeDetailsType(metadata: any Metadata) throws -> RuntimeType.Info {
        throw RuntimeType.IdNeverCalledError()
    }
}

// Static Account doesn't need runtime type
public extension Config where TAccountId: StaticAccountId {
    func accountType(metadata: any Metadata, address: RuntimeType.Info) throws -> RuntimeType.Info {
        throw RuntimeType.IdNeverCalledError()
    }
}

public extension Config where TExtrinsicPayment: Default {
    func defaultPayment(runtime: any Runtime) throws -> TExtrinsicPayment {
        .default
    }
}
