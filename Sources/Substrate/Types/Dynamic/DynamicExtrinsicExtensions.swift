//
//  DynamicExtrinsicExtensions.swift
//  
//
//  Created by Yehor Popovych on 17/08/2023.
//

import Foundation

/// Ensure the runtime version registered in the transaction is the same as at present.
public struct DynamicCheckSpecVersionExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .checkSpecVersion }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial { params }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
    
    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> {
        .uint(UInt256(api.runtime.version.specVersion), id)
    }
}

///// Ensure the transaction version registered in the transaction is the same as at present.
public struct DynamicCheckTxVersionExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .checkTxVersion }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial { params }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
    
    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> {
        .uint(UInt256(api.runtime.version.transactionVersion), id)
    }
}

/// Check genesis hash
public struct DynamicCheckGenesisExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .checkGenesis }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial { params }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
    
    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> {
        try api.runtime.genesisHash.asValue(runtime: api.runtime, type: id)
    }
}

public struct DynamicCheckNonZeroSenderExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .checkNonZeroSender }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial { params }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
    
    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
}

/// Nonce check and increment to give replay protection for transactions.
public struct DynamicCheckNonceExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .checkNonce }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    {
        guard params.nonce == nil else { return params }
        guard let account = params.account else {
            throw ExtrinsicCodingError.parameterNotFound(extension: identifier,
                                                         parameter: "account")
        }
        var params = params
        let nextIndex = try await api.client.accountNextIndex(id: account,
                                                              runtime: api.runtime)
        params.nonce = nextIndex
        return params
    }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id>
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    {
        .uint(UInt256(params.nonce), id)
    }
    
    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
}

/// Check for transaction mortality.
public struct DynamicCheckMortalityExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .checkMortality }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    {
        var params = params
        if params.era == nil {
            params.era = .immortal
        }
        if params.blockHash == nil {
            params.blockHash = try await params.era!.blockHash(api: api)
        }
        return params
    }

    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id>
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    {
        try params.era.asValue(runtime: api.runtime, type: id)
    }

    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id>
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    {
        try params.blockHash.asValue(runtime: api.runtime, type: id)
    }
}

/// Resource limit check.
public struct DynamicCheckWeightExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .checkWeight }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial { params }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
    
    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
}

/// Require the transactor pay for themselves and maybe include a tip to gain additional priority
/// in the queue.
public struct DynamicChargeTransactionPaymentExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .chargeTransactionPayment }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    {
        var params = params
        if params.tip == nil {
            params.tip = try api.runtime.config.defaultPayment(runtime: api.runtime)
        }
        return params
    }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id>
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    {
        try params.tip.asValue(runtime: api.runtime, type: id)
    }

    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
    
    static func tipType(runtime: any Runtime) -> RuntimeType.Info? {
        guard let ext = runtime.metadata.extrinsic.extensions.first(where: {
            $0.identifier == ExtrinsicExtensionId.chargeTransactionPayment.rawValue
        }) else {
            return nil
        }
        return ext.type
    }
}

public struct DynamicPrevalidateAttestsExtension: DynamicExtrinsicExtension {
    public var identifier: ExtrinsicExtensionId { .prevalidateAttests }
    
    public init() {}
    
    public func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial { params }
    
    public func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
    
    public func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id> { .nil(id) }
}