//
//  ZipCrypto.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017年 yaslab. All rights reserved.
//

//import Foundation

class ZipCrypto {
    
    private let crc32Table: [UInt32]
    private var keys = [UInt32]()
    private(set) var header: [UInt8]!
    
    init(password: [CChar], crc32ForCrypting: UInt32?, crc32Table: [UInt32]) {
        self.crc32Table = crc32Table
        
        keys.append(305419896)
        keys.append(591751049)
        keys.append(878082192)
        
        for c in password {
            if c == 0 {
                break
            }
            updateKeys(UInt8(bitPattern: c))
        }
        
        self.header = makeHeader(crc32ForCrypting: crc32ForCrypting)
    }
    
    private func crc32(_ c: UInt32, _ b: UInt32) -> UInt32 {
        let index = Int((c ^ b) & 0xff)
        return crc32Table[index] ^ (c >> 8)
    }

    private func decryptByte() -> UInt8 {
        let temp = (keys[2] & 0xffff) | 2
        let temp2 = ((temp &* (temp ^ 1)) >> 8) & 0xff
        return UInt8(truncatingBitPattern: temp2)
    }
    
    private func updateKeys(_ c: UInt8) {
        keys[0] = crc32(keys[0], UInt32(c))
        keys[1] += keys[0] & 0xff
        keys[1] = keys[1] &* 134775813 &+ 1
        keys[2] = crc32(keys[2], keys[1] >> 24)
    }
    
    func decode(_ c: UInt8) -> UInt8 {
        let cc = c ^ decryptByte()
        updateKeys(cc)
        return cc
    }
    
    func encode(_ c: UInt8) -> UInt8 {
        let t = decryptByte()
        updateKeys(c)
        return t ^ c
    }
    
    private func random() -> UInt8 {
        return UInt8(truncatingBitPattern: arc4random() & 0xff)
    }
    
    private func makeHeader(crc32ForCrypting: UInt32?) -> [UInt8] {
        let headerSize = 12
        var header = [UInt8]()
        for _ in 0 ..< (headerSize - 2) {
            header.append(encode(random()))
        }
        if let crc32ForCrypting = crc32ForCrypting {
            let a = UInt8(truncatingBitPattern: (crc32ForCrypting >> 16) & 0xff)
            let b = UInt8(truncatingBitPattern: (crc32ForCrypting >> 24) & 0xff)
            header.append(encode(a))
            header.append(encode(b))
        } else {
            header.append(encode(random()))
            header.append(encode(random()))
        }
        return header
    }
    
}
