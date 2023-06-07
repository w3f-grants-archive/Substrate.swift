//
//  Ed25519.swift
//  
//
//  Created by Yehor Popovych on 09.05.2021.
//

import Foundation
import Bip39
import ScaleCodec

#if COCOAPODS
import Sr25519
private typealias EDKeyPair = Sr25519.Ed25519KeyPair
private typealias EDSeed = Sr25519.Ed25519Seed
private typealias EDSignature = Sr25519.Ed25519Signature
private typealias EDPublicKey = Sr25519.Ed25519PublicKey
#else
import Ed25519
import Substrate
private typealias EDKeyPair = Ed25519.Ed25519KeyPair
private typealias EDSeed = Ed25519.Ed25519Seed
private typealias EDSignature = Ed25519.Ed25519Signature
private typealias EDPublicKey = Ed25519.Ed25519PublicKey
#endif


public struct Ed25519KeyPair {
    private let _keyPair: EDKeyPair
    private let _pubKey: STEd25519PublicKey
    
    private init(keyPair: EDKeyPair) {
        self._keyPair = keyPair
        self._pubKey = try! STEd25519PublicKey(keyPair.publicKey.raw)
    }
    
    fileprivate static func convertError<T>(_ cb: () throws -> T) throws -> T {
        do {
            return try cb()
        } catch let e as Ed25519Error {
            switch e {
            case .badKeyPairLength:
                throw KeyPairError.native(error: .badPrivateKey)
            case .badPrivateKeyLength:
                throw KeyPairError.input(error: .privateKey)
            case .badPublicKeyLength:
                throw KeyPairError.input(error: .publicKey)
            case .badSeedLength:
                throw KeyPairError.input(error: .seed)
            case .badSignatureLength:
                throw KeyPairError.input(error: .signature)
            }
        } catch {
            throw KeyPairError(error: error)
        }
    }
}

extension Ed25519KeyPair: KeyPair {
    public var raw: Data { _keyPair.raw }
    public var pubKey: any PublicKey { _pubKey }
    public var algorithm: CryptoTypeId { .ed25519 }
    
    public init(phrase: String, password: String? = nil) throws {
        let mnemonic = try Self.convertError {
            try Mnemonic(mnemonic: phrase.components(separatedBy: " "))
        }
        let seed = mnemonic.substrate_seed(password: password ?? "")
        try self.init(seed: Data(seed))
    }
    
    public init(seed: Data) throws {
        let kpSeed = try Self.convertError {
            try EDSeed(raw: seed.prefix(EDSeed.size))
        }
        self.init(keyPair: EDKeyPair(seed: kpSeed))
    }
    
    public init() {
        try! self.init(seed: Data(SubstrateKeychainRandom.bytes(count: EDSeed.size)))
    }
    
    public init(raw: Data) throws {
        let kp = try Self.convertError {
            try EDKeyPair(raw: raw)
        }
        self.init(keyPair: kp)
    }
    
    public func sign(message: Data) -> any Signature {
        return try! STEd25519Signature(raw: _keyPair.sign(message: message).raw)
    }
    
    public func verify(message: Data, signature: any Signature) -> Bool {
        guard signature.algorithm == self.algorithm else {
            return false
        }
        guard let sig = try? EDSignature(raw: signature.raw) else {
            return false
        }
        return _keyPair.verify(message: message, signature: sig)
    }
    
    public static var seedLength: Int = EDSeed.size
}

extension Ed25519KeyPair: KeyDerivable {
    public func derive(path: [PathComponent]) throws -> Ed25519KeyPair {
        let kp = try path.reduce(_keyPair) { (pair, cmp) in
            guard cmp.isHard else { throw KeyPairError.derive(error: .softDeriveIsNotSupported) }
            let encoder = SCALE.default.encoder()
            try encoder.encode("Ed25519HDKD")
            try encoder.encode(_keyPair.privateRaw, .fixed(UInt(EDKeyPair.secretSize)))
            try encoder.encode(cmp.bytes, .fixed(UInt(PathComponent.size)))
            let hash = HBlake2b256.instance.hash(data: encoder.output)
            let seed = try Self.convertError { try EDSeed(raw: hash) }
            return EDKeyPair(seed: seed)
        }
        return Self(keyPair: kp)
    }
}

extension STEd25519PublicKey: KeyDerivable {
    public func derive(path: [PathComponent]) throws -> STEd25519PublicKey {
        throw KeyPairError.derive(error: .softDeriveIsNotSupported)
    }
}

extension STEd25519PublicKey {
    public func verify(signature: any Signature, message: Data) -> Bool {
        guard signature.algorithm == self.algorithm else {
            return false
        }
        guard let pub = try? EDPublicKey(raw: self.raw) else {
            return false
        }
        guard let sig = try? EDSignature(raw: signature.raw) else {
            return false
        }
        return pub.verify(message: message, signature: sig)
    }
}