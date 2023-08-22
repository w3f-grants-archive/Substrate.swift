//
//  DynamicSignedExtensions.swift
//
//
//  Created by Yehor Popovych on 17.01.2023.
//

import Foundation
import ScaleCodec

public protocol DynamicExtrinsicExtension: ExtrinsicSignedExtension {
    func params<R: RootApi>(
        api: R, partial params: R.RC.TSigningParams.TPartial
    ) async throws -> R.RC.TSigningParams.TPartial
        where R.RC.TSigningParams == AnySigningParams<R.RC>

    func extra<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id>
        where R.RC.TSigningParams == AnySigningParams<R.RC>

    func additionalSigned<R: RootApi>(
        api: R, params: R.RC.TSigningParams, id: RuntimeType.Id
    ) async throws -> Value<RuntimeType.Id>
        where R.RC.TSigningParams == AnySigningParams<R.RC>
    
    func validate<C: Config>(
        config: C.Type, runtime: any Runtime,
        extra: RuntimeType.Id, additionalSigned: RuntimeType.Id
    ) -> Result<Void, TypeValidationError> where C.TSigningParams == AnySigningParams<C>
}

public class DynamicSignedExtensionsProvider<RC: Config>: SignedExtensionsProvider where
    RC.TSigningParams == AnySigningParams<RC>
{
    public typealias TConfig = RC
    public typealias TExtra = Value<RuntimeType.Id>
    public typealias TAdditionalSigned = [Value<RuntimeType.Id>]
    
    public let extensions: [ExtrinsicExtensionId: any DynamicExtrinsicExtension]
    public let version: UInt8
    
    public init(extensions: [any DynamicExtrinsicExtension], version: UInt8) {
        self.extensions = Dictionary(uniqueKeysWithValues: extensions.map { ($0.identifier, $0) })
        self.version = version
    }
    
    public func params<R: RootApi<RC>>(partial params: RC.TSigningParams.Partial,
                                       for api: R) async throws -> RC.TSigningParams
    {
        var params = params
        for ext in try _activeExtensions(runtime: api.runtime).get() {
            params = try await ext.ext.params(api: api, partial: params)
        }
        return try RC.TSigningParams(partial: params)
    }
        
    public func extra<R: RootApi<RC>>(params: RC.TSigningParams, for api: R) async throws -> TExtra {
        let extensions = try _activeExtensions(runtime: api.runtime).get()
        var extra: [Value<RuntimeType.Id>] = []
        extra.reserveCapacity(extensions.count)
        for ext in extensions {
            try await extra.append(ext.ext.extra(api: api, params: params, id: ext.extId))
        }
        return try Value(value: .sequence(extra), context: api.runtime.types.extrinsicExtra.id)
    }
    
    public func additionalSigned<R: RootApi<RC>>(params: RC.TSigningParams,
                                                 for api: R) async throws -> TAdditionalSigned
    {
        let extensions = try _activeExtensions(runtime: api.runtime).get()
        var additional: [Value<RuntimeType.Id>] = []
        additional.reserveCapacity(extensions.count)
        for ext in extensions {
            try await additional.append(ext.ext.additionalSigned(api: api, params: params, id: ext.addId))
        }
        return additional
    }
    
    public func encode<E: ScaleCodec.Encoder>(extra: TExtra, in encoder: inout E,
                                              runtime: any Runtime) throws {
        try runtime.encode(value: extra, in: &encoder,
                           as: runtime.types.extrinsicExtra.id)
    }
    
    public func encode<E: ScaleCodec.Encoder>(additionalSigned: TAdditionalSigned,
                                              in encoder: inout E,
                                              runtime: any Runtime) throws {
        let extensions = try _activeExtensions(runtime: runtime).get()
        guard additionalSigned.count == extensions.count else {
            throw ExtrinsicCodingError.badExtrasCount(expected: extensions.count,
                                                      got: additionalSigned.count)
        }
        for (addSigned, ext) in zip(additionalSigned, extensions) {
            try runtime.encode(value: addSigned, in: &encoder, as: ext.addId)
        }
    }
    
    public func extra<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: any Runtime) throws -> TExtra {
        try runtime.decode(from: &decoder, id: runtime.types.extrinsicExtra.id)
    }
    
    public func additionalSigned<D: ScaleCodec.Decoder>(
        from decoder: inout D, runtime: any Runtime
    ) throws -> TAdditionalSigned {
        try _activeExtensions(runtime: runtime).get().map { ext in
            try runtime.decode(from: &decoder, id: ext.addId)
        }
    }
    
    public func validate(
        runtime: any Runtime
    ) -> Result<Void, Either<ExtrinsicCodingError, TypeValidationError>> {
        _activeExtensions(runtime: runtime)
            .mapError {.left($0)}
            .flatMap { exts in
                exts.reduce(.success(())) { p, ext in
                    p.flatMap {
                        ext.ext.validate(
                            config: RC.self, runtime: runtime,
                            extra: ext.extId, additionalSigned: ext.addId
                        ).mapError{.right($0)}
                    }
                }
            }
    }
    
    private func _activeExtensions(
        runtime: any Runtime
    ) -> Result<[(ext: any DynamicExtrinsicExtension, extId: RuntimeType.Id, addId: RuntimeType.Id)],
                ExtrinsicCodingError>
    {
        guard runtime.metadata.extrinsic.version == version else {
            return .failure(.badExtrinsicVersion(
                supported: version,
                got: runtime.metadata.extrinsic.version
            ))
        }
        return runtime.metadata.extrinsic.extensions.resultMap { info in
            let id = ExtrinsicExtensionId(info.identifier)
            guard let ext = self.extensions[id] else {
                return .failure(.unknownExtension(identifier: id))
            }
            return .success((ext, info.type.id, info.additionalSigned.id))
        }
    }
}
