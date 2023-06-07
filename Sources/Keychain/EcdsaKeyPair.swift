//
//  EcdsaKeyPair.swift
//  
//
//  Created by Yehor Popovych on 12.05.2021.
//

import Foundation
import CSecp256k1
import Bip39
import ScaleCodec
#if !COCOAPODS
import Substrate
#endif

public struct EcdsaKeyPair {
    private let _private: [UInt8]
    private let _public: secp256k1_pubkey
    private let _pubKey: EcdsaPublicKey
    
    private init(privKey: [UInt8]) throws {
        guard Self._context.verify(privKey: privKey) else {
            throw KeyPairError.native(error: .badPrivateKey)
        }
        let pub = try Self._context.toPublicKey(privKey: privKey)
        let raw = try Data(Self._context.serialize(pubKey: pub, compressed: true))
        self._public = pub
        self._private = privKey
        self._pubKey = try EcdsaPublicKey(raw)
    }
    
    fileprivate static let _context = Secp256k1Context()
}

extension EcdsaKeyPair: KeyPair {
    public var algorithm: CryptoTypeId { .ecdsa }
    public var pubKey: any PublicKey { _pubKey }
    public var raw: Data { Data(_private) + _pubKey.raw }
    
    public init(phrase: String, password: String? = nil) throws {
        let mnemonic: Mnemonic
        do {
            mnemonic = try Mnemonic(mnemonic: phrase.components(separatedBy: " "))
        } catch {
            throw KeyPairError(error: error)
        }
        let seed = mnemonic.substrate_seed(password: password ?? "")
        try self.init(seed: Data(seed))
    }
    
    public init(seed: Data) throws {
        guard seed.count >= Secp256k1Context.privKeySize else {
            throw KeyPairError.input(error: .seed)
        }
        try self.init(privKey: Array(seed.prefix(Secp256k1Context.privKeySize)))
    }
    
    public init(raw: Data) throws {
        guard raw.count == (Secp256k1Context.privKeySize + Secp256k1Context.compressedPubKeySize) else {
            throw KeyPairError.native(error: .badPrivateKey)
        }
        try self.init(privKey: Array(raw[0..<Secp256k1Context.privKeySize]))
    }
    
    public init() {
        try! self.init(seed: Data(SubstrateKeychainRandom.bytes(count: Secp256k1Context.privKeySize)))
    }
    
    public func sign(message: Data) -> any Signature {
        let hash = HBlake2b256.instance.hash(data: message)
        let signature = try! Self._context.sign(hash: Array(hash), privKey: self._private)
        let raw = try! Data(Self._context.serialize(signature: signature))
        return try! EcdsaSignature(raw: raw)
    }
    
    public func verify(message: Data, signature: any Signature) -> Bool {
        guard signature.algorithm == self.algorithm else {
            return false
        }
        guard let sig = try? Self._context.signature(from: Array(signature.raw)) else {
            return false
        }
        let hash = HBlake2b256.instance.hash(data: message)
        return Self._context.verify(signature: sig, hash: Array(hash), pubKey: self._public)
    }
    
    public static var seedLength: Int = Secp256k1Context.privKeySize
}

extension EcdsaKeyPair: KeyDerivable {
    public func derive(path: [PathComponent]) throws -> EcdsaKeyPair {
        let priv = try path.reduce(_private) { (secret, cmp) in
            guard cmp.isHard else { throw KeyPairError.derive(error: .softDeriveIsNotSupported) }
            let encoder = SCALE.default.encoder()
            try encoder.encode("Secp256k1HDKD")
            try encoder.encode(Data(secret), .fixed(UInt(Secp256k1Context.privKeySize)))
            try encoder.encode(cmp.bytes, .fixed(UInt(PathComponent.size)))
            let hash = HBlake2b256.instance.hash(data: encoder.output)
            return Array(hash.prefix(Secp256k1Context.privKeySize))
        }
        
        return try Self(privKey: priv)
    }
}

extension EcdsaPublicKey: KeyDerivable {
    public func derive(path: [PathComponent]) throws -> EcdsaPublicKey {
        throw KeyPairError.derive(error: .softDeriveIsNotSupported)
    }
}

extension EcdsaPublicKey {
    // Compressed or uncompressed key can be used.
    public init(converting data: Data) throws {
        let pub = try EcdsaKeyPair._context.publicKey(from: Array(data))
        let newData = try EcdsaKeyPair._context.serialize(pubKey: pub, compressed: true)
        try self.init(Data(newData))
    }
    
    public func verify(signature: any Signature, message: Data) -> Bool {
        guard signature.algorithm == self.algorithm else {
            return false
        }
        guard let sig = try? EcdsaKeyPair._context.signature(from: Array(signature.raw)) else {
            return false
        }
        guard let pub = try? EcdsaKeyPair._context.publicKey(from: Array(self.raw)) else {
            return false
        }
        let hash =  HBlake2b256.instance.hash(data: message)
        return EcdsaKeyPair._context.verify(signature: sig, hash: Array(hash), pubKey: pub)
    }
}