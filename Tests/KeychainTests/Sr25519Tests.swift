//
//  Sr25519Tests.swift
//  
//
//  Created by Yehor Popovych on 06.05.2021.
//

import XCTest

#if !COCOAPODS
@testable import SubstrateKeychain
import Substrate
#else
@testable import Substrate
#endif

final class Sr25519Tests: XCTestCase {
    func testSrTestVectorShouldWork() {
        let seed = Hex.decode(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")!
        let pair = try? Sr25519KeyPair(seed: seed)
        let pubKey = try? Sr25519PublicKey(bytes: Hex.decode(hex: "44a996beb1eef7bdcab976ab6d2ca26104834164ecf28fb375600576fcc6eb0f")!, format: .substrate)
        XCTAssertEqual(pair?.pubKey(format: .substrate) as? Sr25519PublicKey, pubKey)
        let message = Data()
        let oSignature = pair?.sign(message: message)
        XCTAssertNotNil(oSignature)
        guard let signature = oSignature else { return }
        XCTAssertEqual(pair?.verify(message: message, signature: signature), true)
    }
    
    func testPhraseInit() {
        let phrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
        let pair = try? Sr25519KeyPair(phrase: phrase)
        let pubBytes = Hex.decode(hex: "46ebddef8cd9bb167dc30878d7113b7e168e6f0646beffd77d69d39bad76b47a")
        XCTAssertEqual(pair?.rawPubKey, pubBytes)
    }
    
    func testDefaultPhraseShouldBeUsed() {
        let p1 = try? Sr25519KeyPair(parsing: "//Alice///password")
        let p2 = try? Sr25519KeyPair(parsing: DEFAULT_DEV_PHRASE + "//Alice", override: "password")
        XCTAssertEqual(p1?.rawPubKey, p2?.rawPubKey)
        
        let p3 = try? Sr25519KeyPair(parsing: DEFAULT_DEV_PHRASE + "/Alice")
        let p4 = try? Sr25519KeyPair(parsing: "/Alice")
        XCTAssertEqual(p3?.rawPubKey, p4?.rawPubKey)
    }
    
    func testDefaultAddressShouldBeUsed() {
        let p1 = try? Sr25519PublicKey(parsing: DEFAULT_DEV_ADDRESS + "/Alice")
        let p2 = try? Sr25519PublicKey(parsing: "/Alice")
        XCTAssertNotNil(p1)
        XCTAssertEqual(p1, p2)
    }
    
    func testDefaultPhraseShouldCorrespondToDefaultAddress() {
        let p1 = try? Sr25519KeyPair(parsing: DEFAULT_DEV_PHRASE + "/Alice")
        let pub1 = try? Sr25519PublicKey(parsing: DEFAULT_DEV_ADDRESS + "/Alice")
        XCTAssertNotNil(p1)
        XCTAssertEqual(p1?.rawPubKey, pub1?.bytes)
        
        let p2 = try? Sr25519KeyPair(parsing: "/Alice")
        let pub2 = try? Sr25519PublicKey(parsing: "/Alice")
        XCTAssertNotNil(p2)
        XCTAssertEqual(p2?.rawPubKey, pub2?.bytes)
    }
    
    func testDeriveSoftShouldWork() {
        let oPair = try? Sr25519KeyPair(seed: Hex.decode(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")!)
        XCTAssertNotNil(oPair)
        guard let pair = oPair else { return }
        let derive1 = try? pair.derive(path: [PathComponent(soft: UInt32(1))])
        let derive1b = try? pair.derive(path: [PathComponent(soft: UInt32(1))])
        XCTAssertNotNil(derive1)
        XCTAssertEqual(derive1?.rawPubKey, derive1b?.rawPubKey)
        let derive2 = try? pair.derive(path: [PathComponent(soft: UInt32(2))])
        XCTAssertNotEqual(derive1?.rawPubKey, derive2?.rawPubKey)
    }
    
    func testDeriveHardShouldWork() {
        let oPair = try? Sr25519KeyPair(seed: Hex.decode(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")!)
        XCTAssertNotNil(oPair)
        guard let pair = oPair else { return }
        let derive1 = try? pair.derive(path: [PathComponent(hard: UInt32(1))])
        let derive1b = try? pair.derive(path: [PathComponent(hard: UInt32(1))])
        XCTAssertNotNil(derive1)
        XCTAssertEqual(derive1?.rawPubKey, derive1b?.rawPubKey)
        let derive2 = try? pair.derive(path: [PathComponent(hard: UInt32(2))])
        XCTAssertNotEqual(derive1?.rawPubKey, derive2?.rawPubKey)
    }
    
    func testDeriveSoftPublicShouldWork() {
        let oPair = try? Sr25519KeyPair(seed: Hex.decode(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")!)
        XCTAssertNotNil(oPair)
        guard let pair = oPair else { return }
        let path = try! [PathComponent(soft: UInt32(1))]
        let pair1 = try? pair.derive(path: path)
        let pub1 = try? pair.publicKey(format: .substrate).derive(path: path)
        XCTAssertNotNil(pair1)
        XCTAssertEqual(pair1?.rawPubKey, pub1?.bytes)
    }
    
    func testDeriveHardPublicShouldFail() {
        let oPair = try? Sr25519KeyPair(seed: Hex.decode(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")!)
        XCTAssertNotNil(oPair)
        guard let pair = oPair else { return }
        let path = try! [PathComponent(hard: UInt32(1))]
        XCTAssertThrowsError(try pair.publicKey(format: .substrate).derive(path: path))
    }
    
    func testGeneratedPairShouldWork() {
        let pair = Sr25519KeyPair()
        let message = Data("Something important".utf8)
        let signature = pair.sign(message: message)
        XCTAssertTrue(pair.verify(message: message, signature: signature))
    }
    
    func testMessedSignatureShouldNotWork() {
        let pair = Sr25519KeyPair()
        let message = Data("Signed payload".utf8)
        var signature = pair.sign(message: message)
        signature[0] = signature[0] << 2
        signature[2] = signature[2] << 1
        XCTAssertFalse(pair.verify(message: message, signature: signature))
    }
    
    func testMessedMessageShouldNotWork() {
        let pair = Sr25519KeyPair()
        let message = Data("Something important".utf8)
        let signature = pair.sign(message: message);
        XCTAssertFalse(pair.verify(message: Data("Something unimportant".utf8), signature: signature))
    }
    
    func testSeededPairShouldWork() {
        let oPair = try? Sr25519KeyPair(seed: Data("12345678901234567890123456789012".utf8))
        XCTAssertNotNil(oPair)
        guard let pair = oPair else { return }
        let expPub = try? Sr25519PublicKey(bytes: Hex.decode(hex: "741c08a06f41c596608f6774259bd9043304adfa5d3eea62760bd9be97634d63")!, format: .substrate)
        XCTAssertEqual(pair.rawPubKey, expPub?.bytes)
        
        let message = Hex.decode(hex: "2f8c6129d816cf51c374bc7f08c3e63ed156cf78aefb4a6550d97b87997977ee00000000000000000200d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a4500000000000000")!
        let signature = pair.sign(message: message)
        XCTAssertTrue(pair.verify(message: message, signature: signature))
    }
    
    func testSs58CheckRoundtripWorks() {
        let pair = Sr25519KeyPair()
        let ss58 = pair.publicKey(format: .substrate).ss58
        let pub = try? Sr25519PublicKey(ss58: ss58)
        XCTAssertEqual(pair.publicKey(format: .substrate), pub)
    }

    
    func testSignAndVerify() {
        let oPair = try? Sr25519KeyPair(seed: Hex.decode(hex: "fac7959dbfe72f052e5a0c3c8d6530f202b02fd8f9f5ca3580ec8deb7797479e")!)
        XCTAssertNotNil(oPair)
        guard let pair = oPair else { return }
        let message = Data("Some awesome message to sign".utf8)
        let signature = pair.sign(message: message)
        let isValid = pair.verify(message: message, signature: signature)
        XCTAssertEqual(isValid, true)
    }
    
    func testCompatibilityDeriveHardKnownPairShouldWork() {
        let pair = try? Sr25519KeyPair(parsing: DEFAULT_DEV_PHRASE + "//Alice")
        // known address of DEV_PHRASE with 1.1
        let known = Hex.decode(hex: "d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d")!
        XCTAssertEqual(pair?.rawPubKey, known)
    }
    
    func testCompatibilityDeriveSoftKnownPairShouldWork() {
        let pair = try? Sr25519KeyPair(parsing: DEFAULT_DEV_PHRASE + "/Alice")
        // known address of DEV_PHRASE with 1.1
        let known = Hex.decode(hex: "d6c71059dbbe9ad2b0ed3f289738b800836eb425544ce694825285b958ca755e")!
        XCTAssertEqual(pair?.rawPubKey, known)
    }
}
